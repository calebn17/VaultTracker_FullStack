# Rate Limiting for VaultTrackerAPI

## Context

VaultTrackerAPI has no rate limiting. It was listed as a planned feature but never implemented. The API has 24 endpoints (21 authenticated, 3 public) deployed on Render. Adding rate limiting addresses abuse prevention, cost control for external API calls (CoinGecko/Alpha Vantage), and production hardening.

## Approach

Use **SlowAPI** (the standard FastAPI rate limiting library) with **in-memory storage**, **per-user keys** for authenticated routes (IP fallback for unauthenticated), and **tiered limits** by endpoint type.

## Key Design Decision: Rate Limit Key Function

SlowAPI's `@limiter.limit()` decorator runs **before** FastAPI dependency injection. The key function receives only a bare `Request` — `get_current_user` hasn't resolved yet. 

**Solution:** The key function peeks at the `Authorization` header and extracts a stable identifier **without full verification** (the rate limiter only needs a key, not authentication — `get_current_user` still handles real auth afterward):

1. If debug auth is enabled and token matches `"vaulttracker-debug-user"` → key is `"user:debug-user"`
2. If a Bearer token is present → **base64-decode the JWT payload segment** (no cryptographic verification) and extract the `sub` claim → key is `"user:{sub}"`. This avoids double-calling `verify_id_token` and removes the Firebase SDK dependency from the rate limiter entirely.
3. If no token or decode fails → fall back to `get_remote_address(request)` (IP-based)

An attacker who forges a JWT to get a different rate-limit bucket will still be rejected by `get_current_user` moments later. The rate limiter only needs a stable key, not a security gate.

## Rate Limit Tiers

| Tier | Default | Env Var | Endpoints | Rationale |
|------|---------|---------|-----------|-----------|
| Read | `60/minute` | `RATE_LIMIT_READ` | All GET on accounts, assets, transactions, dashboard, networth, analytics, fire | Normal browsing pace |
| Write | `30/minute` | `RATE_LIMIT_WRITE` | All POST, PUT, DELETE on accounts, assets, transactions, fire, users | Generous for batch work, prevents abuse |
| External | `10/minute` | `RATE_LIMIT_EXTERNAL` | `POST /prices/refresh`, `GET /prices/{symbol}` | CoinGecko ~10-30/min free; Alpha Vantage 5/min free |
| Health/Root | Exempt | N/A | `GET /`, `GET /health` | Infrastructure endpoints, no limiting needed |

## Files to Create/Modify

### New: `app/rate_limit.py`
- `_decode_jwt_subject(token: str) -> str | None` — base64-decodes JWT payload and extracts `sub` claim (no crypto, no Firebase dependency)
- `get_rate_limit_key(request: Request) -> str` — key function: debug token check → JWT subject decode → IP fallback
- `limiter` — `Limiter` instance with `storage_uri="memory://"`, `key_func=get_rate_limit_key`, `headers_enabled=True`
- `rate_limit_exceeded_handler` — custom 429 handler returning `{"detail": "Rate limit exceeded. ..."}` with `Retry-After` header, plus `logger.warning(...)` for abuse detection

### Modify: `app/config.py`
Add 3 settings to `Settings`:
```python
rate_limit_read: str = "60/minute"
rate_limit_write: str = "30/minute"  
rate_limit_external: str = "10/minute"
```

### Modify: `app/main.py`
- Register `app.state.limiter = limiter`
- Add exception handler for `RateLimitExceeded`
- Add `SlowAPIMiddleware` (after CORS — middleware is LIFO, so CORS preflight OPTIONS handled before rate limiting)
- Add `@limiter.exempt` + `request: Request` param to `root()` and `health_check()`

### Modify: Each router file (9 files)
Add `@limiter.limit(settings.rate_limit_<tier>)` decorator and `request: Request` parameter to every endpoint:

**Read tier** (`settings.rate_limit_read`):
- `accounts.py`: GET /accounts, GET /accounts/{id}
- `assets.py`: GET /assets, GET /assets/{id}
- `transactions.py`: GET /transactions, GET /transactions/{id}
- `dashboard.py`: GET /dashboard
- `networth.py`: GET /networth/history
- `analytics.py`: GET /analytics
- `fire.py`: GET /fire/profile, GET /fire/projection

**Write tier** (`settings.rate_limit_write`):
- `accounts.py`: POST, PUT, DELETE
- `assets.py`: POST
- `transactions.py`: POST, POST /smart, PUT, PUT /smart, DELETE
- `fire.py`: PUT /fire/profile
- `users.py`: DELETE /users/me/data

**External tier** (`settings.rate_limit_external`):
- `prices.py`: POST /prices/refresh, GET /prices/{symbol}

**Pattern per endpoint:**
```python
from starlette.requests import Request
from app.rate_limit import limiter
from app.config import settings

@router.get("", response_model=list[AccountResponse])
@limiter.limit(settings.rate_limit_read)
async def get_accounts(
    request: Request,  # added for SlowAPI
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
```

### Modify: `requirements.txt`
Add `slowapi>=0.1.9`

### New: `tests/test_rate_limiting.py`
Tests with lowered limits (monkeypatched):
1. Read endpoint returns 429 after exceeding limit
2. Write endpoint has separate counter from read
3. External endpoint is strictest
4. Per-user isolation (user A exhausted, user B still works)
5. 429 response body matches `{"detail": "..."}` format with `Retry-After` header
6. Exempt endpoints (/, /health) never return 429
7. Success responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers

### Modify: `tests/conftest.py`
Reset limiter storage between tests in `_reset_database_and_cache` fixture.

### Testing note
The existing `conftest.py` overrides `get_current_user` entirely, so no `Authorization` header is sent in tests. The key function will fall back to IP-based limiting in tests. For per-user isolation tests, we'll monkeypatch `get_rate_limit_key` to return controlled keys.

## Pitfalls
1. **`request: Request` required on every decorated endpoint** — SlowAPI fails if missing. `prices.py` `get_price` currently only takes `symbol: str` — must add `request: Request`.
2. **Middleware ordering** — `SlowAPIMiddleware` added after `CORSMiddleware` so CORS preflight isn't rate-limited. SlowAPI's limiting is decorator-based (not blanket middleware), so OPTIONS requests that never reach a decorated handler are naturally excluded.
3. **`X-Forwarded-For` behind Render** — SlowAPI's `get_remote_address` reads `X-Forwarded-For` by default, which is correct for Render's reverse proxy. Verify during implementation.
4. **Single-worker only** — in-memory storage doesn't share across uvicorn workers; fine for current single-process Render deployment.
5. **Test client fixture** — the `client` fixture overrides `get_current_user`, bypassing the Authorization header. Rate limit tests will monkeypatch `get_rate_limit_key` to return controlled keys for per-user isolation testing.
6. **`GET /prices/{symbol}` is unauthenticated** — IP-based limiting may be imperfect behind a proxy. Accepted risk for a personal app; can revisit if abuse occurs.

## Verification
1. Run `pytest tests/ -v` — all existing + new rate limit tests pass
2. Run `ruff format --check . && ruff check --select E,F,I .` — no lint issues
3. Manual test: `curl` an endpoint repeatedly and verify 429 after threshold
4. Check response headers include `X-RateLimit-*` on success and `Retry-After` on 429

## Documentation Update
Update `Documentation/VaultTracker System Design.md` with rate limiting architecture, tiers, and configuration.
