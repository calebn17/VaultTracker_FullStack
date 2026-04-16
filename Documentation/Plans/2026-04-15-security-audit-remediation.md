# Security Audit — Gap Remediation Plan

## Context

A security audit of all three VaultTracker sub-projects (API, Web, iOS) revealed several gaps. This plan addresses the actionable findings, prioritized by severity. iOS findings are mostly informational (no code changes needed beyond input validation alignment). The bulk of the work is in the **API** (input validation hardening) and **Web** (security headers).

---

## Findings Summary

| # | Area | Severity | Sub-project |
|---|------|----------|-------------|
| 1 | `.env` with secrets tracked in git | HIGH | API |
| 2 | `GoogleService-Info.plist` tracked in git | HIGH | iOS |
| 3 | No CSP or security headers | HIGH | Web |
| 4 | Weak input validation on legacy schemas | MEDIUM | API |
| 5 | No max-length on string fields (API schemas) | MEDIUM | API |
| 6 | `debug: bool = True` default in config | MEDIUM | API |
| 7 | Price refresh error leaks internal details | LOW | API |
| 8 | Firebase config error leaks server guidance | LOW | API |

### Out of scope (informational only)
- **SQL injection**: No vulnerabilities found — all queries use SQLAlchemy ORM with parameterized filters.
- **Prompt injection / LLM**: No LLM code exists anywhere in the app.
- **Rate limiting**: Already well-implemented via SlowAPI on all endpoints.
- **iOS debug auth bypass**: Properly guarded behind `#if DEBUG`.
- **iOS certificate pinning**: Recommended but not a code change in this plan (requires infrastructure decision).
- **iOS OSLog `privacy: .public`**: Noted; no PII is currently logged. Future hardening item.

---

## Implementation Steps

### Step 1: Remove `.env` from git tracking (API)

**File:** `VaultTrackerAPI/.env`, `.gitignore`

1. Add `VaultTrackerAPI/.env` to root `.gitignore` (if not already covered by a pattern).
2. Run `git rm --cached VaultTrackerAPI/.env` to untrack without deleting the local file.
3. Verify `.env.example` already exists with placeholder values (it does).
4. **Note:** The Alpha Vantage API key in `.env` (`MTI6BQF066SXWM62`) is now exposed in git history. User should rotate it after this lands.

### Step 2: Remove `GoogleService-Info.plist` from git tracking (iOS)

**File:** `VaultTrackerIOS/VaultTracker/GoogleService-info.plist`, `.gitignore`

1. Add `VaultTrackerIOS/VaultTracker/GoogleService-info.plist` to `.gitignore`.
2. Run `git rm --cached VaultTrackerIOS/VaultTracker/GoogleService-info.plist`.
3. Create `VaultTrackerIOS/VaultTracker/GoogleService-info.plist.example` with placeholder values so new devs know the required structure.
4. **Note:** Firebase API keys are semi-public by design, but best practice for a financial app is to restrict them in Google Cloud Console.

### Step 3: Add security headers to Web app

**File:** `VaultTrackerWeb/next.config.ts`

Add a `headers()` function to the Next.js config returning security headers for all routes:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://vaulttracker-api.onrender.com https://identitytoolkit.googleapis.com https://*.firebaseio.com; frame-ancestors 'none'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

CSP will need tuning — especially `script-src` may need `'unsafe-eval'` or nonces depending on Next.js runtime behavior. We'll verify with `npm run build && npm run start` and browser console.

### Step 4: Harden API input validation (schemas)

**Files:**
- `VaultTrackerAPI/app/schemas/account.py`
- `VaultTrackerAPI/app/schemas/asset.py`
- `VaultTrackerAPI/app/schemas/transaction.py`

Changes:

**account.py** — Add `Literal` validation for `account_type` and `max_length` on `name`:
```python
from typing import Literal
ACCOUNT_TYPE = Literal["cryptoExchange", "brokerage", "bank", "retirement", "other"]

class AccountBase(BaseModel):
    name: str = Field(max_length=200)
    account_type: ACCOUNT_TYPE
```

**asset.py** — Add `Literal` for `category`, `max_length` on strings, `ge=0` on numerics:
```python
ASSET_CATEGORY = Literal["crypto", "stocks", "cash", "realEstate", "retirement"]

class AssetBase(BaseModel):
    name: str = Field(max_length=200)
    symbol: str | None = Field(default=None, max_length=20)
    category: ASSET_CATEGORY
    quantity: float = Field(default=0.0, ge=0)
    current_value: float = Field(default=0.0, ge=0)
```

**transaction.py** — Add validation to legacy `TransactionCreate`/`TransactionUpdate`:
```python
class TransactionBase(BaseModel):
    asset_id: str
    account_id: str
    transaction_type: Literal["buy", "sell"]
    quantity: float = Field(gt=0)
    price_per_unit: float = Field(gt=0)
    date: datetime | None = None
```

Also add `max_length` constraints to `SmartTransactionCreate` string fields (`asset_name`, `symbol`, `account_name`).

### Step 5: Fix `debug` default in config

**File:** `VaultTrackerAPI/app/config.py`

Change line 14 from `debug: bool = True` to `debug: bool = False`. Local devs who need debug mode can set `DEBUG=true` in `.env`.

### Step 6: Sanitize error messages

**File:** `VaultTrackerAPI/app/services/price_service.py` (line 139)

Replace `str(e)` with a generic message:
```python
errors.append({"symbol": asset.symbol, "error": "Price fetch failed"})
```

**File:** `VaultTrackerAPI/app/dependencies.py` (Firebase config error)

Replace the detailed Firebase config guidance with a generic `"Authentication service unavailable"` message.

### Step 7: Update tests

**Files:** `VaultTrackerAPI/tests/`

- Update any tests that create accounts/assets/transactions with invalid `account_type`, `category`, or `transaction_type` values (they should now get 422 validation errors).
- Add tests verifying that oversized strings and negative quantities are rejected.
- Verify existing tests still pass with the stricter schemas.

### Step 8: Update system design doc

**File:** `Documentation/VaultTracker System Design.md`

Add a "Security" section documenting: input validation constraints, security headers on web, secrets management approach.

---

## Verification

1. **API tests:** `cd VaultTrackerAPI && ./venv/bin/python -m pytest tests/ -v`
2. **API lint:** `cd VaultTrackerAPI && ./venv/bin/ruff format --check . && ./venv/bin/ruff check --select E,F,I .`
3. **Web build:** `cd VaultTrackerWeb && npm run build` (verify no CSP-related build issues)
4. **Web lint:** `cd VaultTrackerWeb && npm run lint`
5. **Git status:** Confirm `.env` and `GoogleService-Info.plist` are no longer tracked
6. **Manual:** Open web app in browser, check DevTools console for CSP violations; check response headers include security headers

---

## Critical Files

- `VaultTrackerAPI/app/schemas/account.py`
- `VaultTrackerAPI/app/schemas/asset.py`
- `VaultTrackerAPI/app/schemas/transaction.py`
- `VaultTrackerAPI/app/config.py`
- `VaultTrackerAPI/app/services/price_service.py`
- `VaultTrackerAPI/app/dependencies.py`
- `VaultTrackerWeb/next.config.ts`
- `.gitignore`
