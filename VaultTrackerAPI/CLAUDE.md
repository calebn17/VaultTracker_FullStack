# CLAUDE.md

This file provides guidance to AI coding agents (Claude Code, Cursor, etc.) when working in this repository.

## Collaboration (learning mode)

Primary maintainer context: **iOS developer**, newer to **FastAPI / Python / SQLAlchemy**. When making or reviewing changes, keep them in the loop:

1. **What** — Which files changed and the new behavior (PR-summary style).
2. **Why** — The problem, spec requirement, or tradeoff driving the change.
3. **Diff walkthrough** — Walk important hunks in a sensible order (imports → config → main code path → edge cases).
4. **iOS bridge** — Short analogies where they help (e.g. FastAPI routes as HTTP handlers, `Depends()` as dependency injection, Pydantic as validation + shapes like `Codable`, SQLAlchemy session as “unit of work” toward the DB — note differences from Core Data/SwiftData).
5. **Pitfalls** — Call out things that often confuse iOS devs: sync vs async handlers, when `db.commit()` runs, environment variables vs Xcode schemes, CORS as browser-focused origin rules (not the same as App Transport Security).

If they want less narration, they can ask for a **shorter** summary; if they want more, they can ask for **line-by-line** explanation.

**Backend roadmap:** [Documentation/VaultTracker_Backend_2.0_Spec.md](Documentation/VaultTracker_Backend_2.0_Spec.md)

## Local Development Setup

### Database options

**PostgreSQL via Docker Compose (current default — matches production)**

The `.env` already points at local Docker Postgres:
```
DATABASE_URL=postgresql://vaulttracker:vaulttracker_dev_password@localhost:5432/vaulttracker
```

```bash
# Start container (data persists across stop/start)
docker compose -f docker-compose.postgres.yml up -d

# Check status / readiness
docker compose -f docker-compose.postgres.yml ps
docker exec vaulttracker-postgres pg_isready -U vaulttracker -d vaulttracker

# Stop (keep data)
docker compose -f docker-compose.postgres.yml down

# Full reset (wipes data volume)
docker compose -f docker-compose.postgres.yml down -v
```

Tables are created automatically on startup — no Alembic needed.

**SQLite (no Docker required)**

Swap `.env` if you want the zero-setup option:
```
DATABASE_URL=sqlite:///./vaulttracker.db
```
The DB file lives at `VaultTrackerAPI/vaulttracker.db`. Tables are still auto-created.

### iOS Simulator vs real device

The iOS app uses a compile-time flag to select the backend:

| Launch method | Build config | Backend target |
|---|---|---|
| Simulator via Xcode | DEBUG | `localhost:8000` |
| Real device via Xcode | DEBUG | `localhost:8000` (fails — see below) |
| Archive → TestFlight/App Store | RELEASE | `https://vaulttracker-api.onrender.com` |

**Real device fix:** `localhost` on a physical iPhone means the phone itself, not your Mac. Set `API_HOST` to your Mac's LAN IP in the Xcode scheme:

Xcode → Edit Scheme → Run → Arguments → Environment Variables:
```
API_HOST = 192.168.x.x:8000
```

Find your Mac's LAN IP in System Settings → Wi-Fi → Details. Both devices must be on the same Wi-Fi network.

### Production vs local `.env`

Your local `.env` is never deployed. Render injects its own environment variables (including the Neon `DATABASE_URL`) at runtime via the Render dashboard. The two environments are fully independent.

## Commands

```bash
# One-time: create venv and install deps (from VaultTrackerAPI/)
# Use 3.10+ (macOS `python3` may be 3.9; code uses PEP 604 `X | Y` unions).
python3.10 -m venv venv
./venv/bin/pip install -r requirements.txt

# Optional: activate venv for a shell session (then pip/pytest work without a prefix)
source venv/bin/activate

# Run dev server (auto-reload on changes) — with venv activated, or:
./venv/bin/uvicorn app.main:app --reload

# Interactive API docs (while server is running)
open http://localhost:8000/docs
```

Run automated checks (always use the venv interpreter — macOS `/usr/bin/python3` or Xcode’s Python often has **no pytest**):

```bash
cd VaultTrackerAPI
./venv/bin/python -m pytest tests/ -v
```

Single file:

```bash
./venv/bin/python -m pytest tests/test_analytics_dashboard_cache.py -q
```

`tests/conftest.py` swaps in an in-memory SQLite DB and auth overrides so tests do not touch `vaulttracker.db` or Firebase. For exploratory checks, Swagger at `/docs` or curl with a Bearer token still work.

**Falsification check** (prove failures surface when behavior is wrong):

```bash
VT_BREAK_TESTS=1 ./venv/bin/python -m pytest tests/ -q
```

Expect multiple failures. If the suite still passes, widen `_vt_inject_broken_behavior_for_falsification_checks` in `tests/conftest.py` or fix vacuous assertions. Omit `VT_BREAK_TESTS` for normal runs.

## Architecture

This is a **FastAPI + SQLAlchemy** backend serving the VaultTracker iOS app (default local DB is **SQLite**; set `DATABASE_URL` for **PostgreSQL** e.g. Neon). All routes are mounted under `/api/v1`.

### Project layout

```
app/
  main.py          # App factory, router mounts, lifespan (create_all)
  config.py        # Pydantic Settings, reads .env
  database.py      # SQLAlchemy engine + SessionLocal + Base
  dependencies.py  # get_current_user — the auth dependency
  models/          # SQLAlchemy ORM models
  schemas/         # Pydantic request/response models
  routers/         # accounts, assets, transactions, networth, dashboard, users, analytics, prices
  services/        # asset_sync, transaction_service, analytics_service, price_service, cache_service
```

### Authentication

Every protected route injects `Depends(get_current_user)` ([app/dependencies.py](app/dependencies.py)). When `FIREBASE_CREDENTIALS_PATH` points to a service account JSON, Bearer tokens are verified with **Firebase Admin** and `uid` becomes `firebase_id`. If Firebase is not configured, only the **debug bypass** works (or you get 503 for real tokens). Users are auto-created on first request.

**Debug bypass:** Set `DEBUG_AUTH_ENABLED=true` in `.env` and send `Authorization: Bearer vaulttracker-debug-user`. This maps to the fixed `firebase_id` `"debug-user"` so the same DB row is reused across restarts. This must stay disabled in any non-local environment and must match `AuthTokenProvider.debugToken` in the iOS client.

### The transaction → asset → snapshot chain

The most important invariant: **any write to `transactions` must keep the parent `Asset` and a `NetWorthSnapshot` in sync** (helpers in [app/services/asset_sync.py](app/services/asset_sync.py)):

1. `update_asset_from_transaction` adjusts `asset.quantity` and resets `asset.current_value = quantity * price_per_unit` (mark-to-market, not cost-basis).
2. `record_networth_snapshot` sums `current_value` across all user assets and writes a new `NetWorthSnapshot` row.
3. Both are called inside the same DB transaction before `db.commit()`.

Transaction updates reverse the old effect first (`is_reversal=True`), then apply the new values.

### Dashboard category keys

The dashboard router ([app/routers/dashboard.py](app/routers/dashboard.py)) groups assets into five camelCase buckets: `crypto`, `stocks`, `cash`, `realEstate`, `retirement`. These keys must stay in sync with `DashboardMapper` in the iOS client — renaming them is a breaking change.

### iOS–API contract points

- `account_type` values (`cryptoExchange`, `brokerage`, `bank`, `retirement`, `other`) map to iOS `AccountType` via `AccountMapper.mapAccountType`.
- `asset.category` must be one of the five buckets above.
- `transaction_type` is `"buy"` or `"sell"` (lowercase strings).

### Settings

Loaded from `.env` via pydantic-settings ([app/config.py](app/config.py)):

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./vaulttracker.db` | Use `postgresql://...` for Neon / Render |
| `DEBUG_AUTH_ENABLED` | `false` | Enables iOS debug token bypass |
| `ALLOWED_ORIGINS` | localhost 3000/8000 (see `config.py`) | Comma-separated CORS origins |
| `FIREBASE_CREDENTIALS_PATH` | (empty) | Service account JSON; required for real JWT verification |
| `ALPHA_VANTAGE_API_KEY` | (empty) | Stock quotes (`/prices`, refresh) |

Database tables are created automatically via `Base.metadata.create_all` in the lifespan handler — there are no migration scripts.
