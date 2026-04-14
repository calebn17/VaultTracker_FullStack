---
tags:
  - vaultTracker
  - python
  - backend
title: Vault Tracker - Backend Context
---

# VaultTrackerAPI — Technical Overview

> **Purpose:** Agent-consumable reference. Covers architecture, data model, business logic, all endpoints, auth, and known caveats. Read this before modifying any backend code.

---

## Stack

| Layer | Technology |
|---|---|
| Runtime | Python 3.11+ |
| Framework | FastAPI 0.115+ |
| ORM | SQLAlchemy 2.x (sync session) |
| Database | SQLite (`vaulttracker.db`, file on disk) |
| Validation | Pydantic v2 |
| Config | pydantic-settings (reads `.env`) |
| Server | Uvicorn with `--reload` |

Start command: `./start.sh` → runs `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`

Interactive docs at `http://localhost:8000/docs` (Swagger UI).

---

## Directory Layout

```
VaultTrackerAPI/
├── app/
│ ├── main.py # FastAPI app, lifespan, router mounts, CORS
│ ├── config.py # Settings (pydantic-settings, reads .env)
│ ├── database.py # SQLAlchemy engine, SessionLocal, Base, get_db()
│ ├── dependencies.py # get_current_user() auth dependency
│ ├── models/ # SQLAlchemy ORM models (one per table)
│ │ ├── user.py
│ │ ├── account.py
│ │ ├── asset.py
│ │ ├── transaction.py
│ │ └── networth_snapshot.py
│ ├── schemas/ # Pydantic request/response schemas (one per domain)
│ │ ├── account.py
│ │ ├── asset.py
│ │ ├── transaction.py
│ │ ├── dashboard.py
│ │ ├── networth.py
│ │ └── user.py
│ └── routers/ # FastAPI routers (one per domain)
│ ├── accounts.py
│ ├── assets.py
│ ├── transactions.py
│ ├── dashboard.py
│ ├── networth.py
│ └── users.py
├── .env # Local config (not committed)
├── requirements.txt
├── start.sh
└── vaulttracker.db # SQLite file (git-ignored)
```

---

## Configuration (`.env`)

| Key | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./vaulttracker.db` | SQLAlchemy connection string |
| `DEBUG` | `true` | General debug flag |
| `DEBUG_AUTH_ENABLED` | `false` | Enables the debug auth bypass (see Auth section) |

Settings are loaded via `app/config.py` → `Settings(BaseSettings)`. All routes read from the singleton `settings` object.

---

## Authentication

Every protected route uses `Depends(get_current_user)` from `app/dependencies.py`.

**Normal flow (production intent):**

1. Client sends `Authorization: Bearer <firebase_jwt>`.
2. `get_current_user` strips `Bearer `, extracts the token string.
3. **⚠️ Firebase JWT verification is not yet implemented.** The raw token string is used directly as `firebase_id`. This means any string is accepted as an identity in the current build.
4. The User row matching `firebase_id` is looked up. If absent, a new User row is auto-created (no separate sign-up endpoint needed).
5. The `User` ORM object is injected into the route handler.

**Debug bypass:**

- Enabled when `DEBUG_AUTH_ENABLED=true` in `.env`.
- Token value `"vaulttracker-debug-user"` maps to a fixed `firebase_id = "debug-user"`.
- Matches `AuthTokenProvider.debugToken` in the iOS client.
- Must be `false` in any non-local environment.

**All data is user-scoped.** Every query filters by `user_id == current_user.id`. Cross-user access returns 404.

---

## Data Model

### Entity Relationships

```
User (1) ──< Account (many)
User (1) ──< Asset (many)
User (1) ──< Transaction (many)
User (1) ──< NetWorthSnapshot (many)
Transaction >── Asset (many-to-one)
Transaction >── Account (many-to-one)
```

All PKs are string UUIDs generated server-side (`str(uuid.uuid4())`). All cascade deletes flow from User down.

### Tables

#### `users`

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `firebase_id` | String UNIQUE | Lookup key; used as auth identity |
| `email` | String nullable | Not yet populated by any endpoint |
| `created_at` | DateTime(tz) | UTC |

#### `accounts`

Financial institution holding assets (brokerage, bank, crypto exchange).

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `name` | String | Display name |
| `account_type` | String | `cryptoExchange`, `brokerage`, `bank`, etc. — maps to iOS `AccountType` enum |
| `created_at` | DateTime(tz) | |

#### `assets`

A single financial holding (e.g. "Bitcoin", "AAPL", "Savings").

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `name` | String | |
| `symbol` | String nullable | Ticker; null for cash/real estate |
| `category` | String | `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |
| `quantity` | Float | Maintained by transaction writes |
| `current_value` | Float | `quantity × latest_price_per_unit` (mark-to-market) |
| `last_updated` | DateTime(tz) | Auto-updated on transaction writes |

#### `transactions`

A single buy or sell event.

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `asset_id` | String FK → assets.id | |
| `account_id` | String FK → accounts.id | |
| `transaction_type` | String | `buy` or `sell` |
| `quantity` | Float | Units bought/sold |
| `price_per_unit` | Float | Price at time of transaction |
| `date` | DateTime(tz) | Defaults to `utcnow()` if not supplied |

#### `networth_snapshots`

Historical net worth data points for the chart.

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `date` | DateTime(tz) | Time of snapshot |
| `value` | Float | Sum of all asset `current_value` at snapshot time |

---

## Core Business Logic

### Asset Value Tracking (Mark-to-Market)

`update_asset_from_transaction()` in `routers/transactions.py` is called on every transaction create, update, and delete.

- **Buy:** `asset.quantity += transaction.quantity`
- **Sell:** `asset.quantity -= transaction.quantity`
- After adjustment: `asset.current_value = asset.quantity × price_per_unit`

This is **not** a cost-basis/average-price calculation. The most recent `price_per_unit` supplied re-prices the entire position. For example, buying 1 BTC at $40k and then buying another 1 BTC at $50k will result in `current_value = 2 × $50k = $100k`.

For **updates**, the old transaction effect is reversed (`is_reversal=True`) before applying the new values.

For **deletes**, the transaction effect is reversed then the row is removed.

### Net Worth Snapshots

`record_networth_snapshot()` in `routers/transactions.py` is called after every successful transaction create, update, or delete (before `db.commit()`).

It sums `current_value` across all of the user's assets and inserts a new `NetWorthSnapshot` row. This means snapshots grow unbounded — one row per transaction mutation. No deduplication or aggregation is performed.

---

## API Endpoints

All routes share the prefix `/api/v1`. All routes except `GET /` and `GET /health` require the `Authorization: Bearer <token>` header.

### Health / Root

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/` | No | Version ping |
| GET | `/health` | No | Liveness check |

### Accounts — `/api/v1/accounts`

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| GET | `/accounts` | — | `[AccountResponse]` | All accounts for user |
| POST | `/accounts` | `AccountCreate` | `AccountResponse` 201 | Create account |
| GET | `/accounts/{id}` | — | `AccountResponse` | 404 if not owned |
| PUT | `/accounts/{id}` | `AccountUpdate` (partial) | `AccountResponse` | Partial update via `exclude_unset` |
| DELETE | `/accounts/{id}` | — | 204 | Cascades to transactions |

`AccountCreate`: `{ name: str, account_type: str }`

`AccountUpdate`: `{ name?: str, account_type?: str }`

### Assets — `/api/v1/assets`

| Method | Path | Query | Body | Response | Notes |
|---|---|---|---|---|---|
| GET | `/assets` | `?category=` | — | `[AssetResponse]` | Optional category filter |
| POST | `/assets` | — | `AssetCreate` | `AssetResponse` 201 | Does not auto-create transaction |
| GET | `/assets/{id}` | — | — | `AssetResponse` | 404 if not owned |

`AssetCreate`: `{ name, symbol?, category, quantity=0.0, current_value=0.0 }`

> Assets are typically created first via `POST /assets`, then transactions are posted against them. The asset's `quantity` and `current_value` are updated only by transaction writes — not by directly editing the asset.

### Transactions — `/api/v1/transactions`

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| GET | `/transactions` | — | `[TransactionResponse]` | All transactions for user |
| POST | `/transactions` | `TransactionCreate` | `TransactionResponse` 201 | Also updates asset + records snapshot |
| GET | `/transactions/{id}` | — | `TransactionResponse` | 404 if not owned |
| PUT | `/transactions/{id}` | `TransactionUpdate` (partial) | `TransactionResponse` | Reverses old effect, applies new, records snapshot |
| DELETE | `/transactions/{id}` | — | 204 | Reverses asset effect, records snapshot |

`TransactionCreate`: `{ asset_id, account_id, transaction_type: "buy"|"sell", quantity, price_per_unit, date? }`

`TransactionUpdate`: `{ transaction_type?, quantity?, price_per_unit?, date? }`

> Validation: `asset_id` and `account_id` must both belong to the authenticated user or 404 is returned.

### Dashboard — `/api/v1/dashboard`

| Method | Path | Response |
|---|---|---|
| GET | `/dashboard` | `DashboardResponse` |

Response shape:

```json
{
  "totalNetWorth": 150000.0,
  "categoryTotals": {
    "crypto": 50000.0,
    "stocks": 80000.0,
    "cash": 20000.0,
    "realEstate": 0.0,
    "retirement": 0.0
  },
  "groupedHoldings": {
    "crypto": [{ "id", "name", "symbol", "quantity", "current_value" }],
    "stocks": [...],
    ...
  }
}
```

Computed server-side from the current state of all assets. Does not read from snapshots. Category keys are **camelCase** and must stay in sync with iOS `DashboardMapper`.

### Net Worth History — `/api/v1/networth`

| Method | Path | Query | Response |
|---|---|---|---|
| GET | `/networth/history` | `?period=daily\|weekly\|monthly` | `NetWorthHistoryResponse` |

Response: `{ "snapshots": [{ "date": ISO8601, "value": float }] }` ordered oldest-first.

> `period` parameter is accepted but **not yet implemented** — all snapshots are always returned regardless of period value.

### Users — `/api/v1/users`

| Method | Path | Response | Notes |
|---|---|---|---|
| DELETE | `/users/me/data` | 204 | Wipes all financial data, preserves user row |

Delete order: transactions → snapshots → assets → accounts (respects FK constraints).

Primarily used by integration tests to reset state between runs.

---

## Known Gaps / TODOs

1. **Firebase JWT not verified.** `get_current_user` trusts the raw token string as the `firebase_id`. Real JWT verification (`firebase-admin` SDK) is needed before production.
2. **`period` filter unimplemented** on `GET /networth/history`. Currently returns all snapshots.
3. **Snapshot accumulation.** A new snapshot row is written on every transaction write. No pruning or downsampling strategy exists yet.
4. **`current_value` is mark-to-market, not cost-basis.** The latest `price_per_unit` re-prices the entire position. Cost-basis or average-price tracking would require a different model.
5. **No pagination** on list endpoints. All records for the user are returned in a single response.
6. **SQLite only.** `connect_args={"check_same_thread": False}` is set, but SQLite is not suitable for concurrent production writes. Migration to PostgreSQL would require removing that arg and adjusting the connection string.
7. **CORS is fully open** (`allow_origins=["*"]`). Must be restricted before production deployment.

---

## iOS Client Integration Notes

- **Auth token:** iOS sends `Authorization: Bearer vaulttracker-debug-user` in debug builds (matches `AuthTokenProvider.debugToken`). Requires `DEBUG_AUTH_ENABLED=true` in `.env`.
- **Category strings** must match exactly: `crypto`, `stocks`, `cash`, `realEstate`, `retirement`.
- **Account type strings** map to the iOS `AccountType` enum via `AccountMapper.mapAccountType`.
- **Dashboard response** keys are camelCase (`totalNetWorth`, `categoryTotals`, `groupedHoldings`) to match iOS `DashboardMapper`.
- The iOS app does **not** write snapshots directly — all snapshot management is server-side via the transaction router.
