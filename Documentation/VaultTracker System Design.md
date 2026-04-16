---
tags:
  - vaultTracker
  - systemDesign
title: Vault Tracker - System Design
date: 2026-03-22
---

# VaultTracker — System Design

> A comprehensive technical design document covering the full system: iOS app, Python/FastAPI backend (v1 and v2), and Next.js web app.

---

## 1. Product Overview

VaultTracker is a personal net-worth tracker that lets users log financial transactions (buy/sell) across five asset categories — **Crypto, Stocks/ETFs, Cash, Real Estate, Retirement** — and view a live net-worth total with a historical chart. The system consists of three clients (iOS app, web app) sharing a single backend and identity provider.

### Core User Flows

1. **Sign in** with Google via Firebase Auth
2. **Record a transaction** (buy/sell an asset) → backend auto-creates the asset and account if they don't exist
3. **View dashboard** — total net worth, category breakdown, per-asset holdings
4. **View analytics** — allocation percentages, gain/loss, cost basis
5. **Refresh prices** — pull live crypto/stock prices from CoinGecko and Alpha Vantage
6. **View net worth history** — time-series chart with daily/weekly/monthly granularity

---

## 2. System Architecture

### High-Level Diagram

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│       iOS App               │     │         Web App               │
│  Swift / SwiftUI            │     │  Next.js 14+ / TypeScript     │
│                             │     │                               │
│  AuthManager (Firebase)     │     │  Auth Context (Firebase Web)  │
│  DataService → APIService   │     │  TanStack React Query         │
│  URLSession + JWT           │     │  Native fetch + JWT           │
└──────────────┬──────────────┘     └──────────────┬───────────────┘
               │  REST JSON /api/v1                 │
               └──────────────────┬─────────────────┘
                                  │
               ┌──────────────────▼─────────────────┐
               │        VaultTrackerAPI              │
               │        Python / FastAPI             │
               │                                     │
               │  dependencies.py  ← Firebase JWT    │
               │  routers/         ← HTTP handlers   │
               │  services/        ← Business logic  │
               │  models/          ← SQLAlchemy ORM  │
               │  schemas/         ← Pydantic I/O    │
               │                                     │
               │  PostgreSQL (Neon)                  │
               │  In-Memory Cache (cachetools)        │
               └──────────┬──────────────────────────┘
                          │
          ┌───────────────┴──────────────┐
          │                              │
   ┌──────▼──────┐               ┌───────▼──────┐
   │  CoinGecko  │               │ Alpha Vantage │
   │  (crypto)   │               │   (stocks)   │
   └─────────────┘               └──────────────┘
```

### Identity Provider

Firebase Auth is the single identity layer. Both the iOS app and the web app authenticate with Google via Firebase. The backend verifies Firebase JWTs using the Firebase Admin SDK. All user data is partitioned by `firebase_id` (the stable Firebase UID).

### Security

- **Secrets and git** — `VaultTrackerAPI/.env` and the iOS Firebase client plist (`GoogleService-Info.plist`) must remain **untracked**. Use `VaultTrackerAPI/.env.example` and `VaultTrackerIOS/VaultTracker/GoogleService-Info.plist.example` as templates. CI copies the example to `GoogleService-Info.plist` before building. Rotate any credentials that may have appeared in git history.
- **API input validation** — Pydantic schemas constrain `account_type`, asset `category`, and `transaction_type` to the documented string unions; string fields use `max_length`; quantities and `price_per_unit` are positive where the contract requires it; smart-transaction string fields are bounded. Invalid payloads return HTTP 422.
- **API defaults and errors** — Application `debug` defaults to **false** in settings (override with `DEBUG=true` in a local `.env` only). Price refresh errors and Firebase initialization failures return **generic** client-facing messages without leaking stack traces or server configuration hints.
- **Web headers** — The Next.js app sets **Content-Security-Policy** (tuned for Firebase Auth, the REST API base URL, Sentry ingest, and local dev), plus `X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`, `Referrer-Policy`, and `Permissions-Policy` via `VaultTrackerWeb/next.config.ts`. Adjust `connect-src` when adding new third-party origins. Production `script-src` still allows `'unsafe-inline'` (Next.js hydration/RSC); stricter **nonce-based** CSP is a future hardening step.

---

## 3. Backend

### 3.1 Stack

| Layer       | Technology                                      |
| ----------- | ----------------------------------------------- |
| Runtime     | Python 3.11+                                    |
| Framework   | FastAPI 0.115+                                  |
| ORM         | SQLAlchemy 2.x (sync session)                   |
| Database    | PostgreSQL on Neon (migrated from SQLite)       |
| Validation  | Pydantic v2                                     |
| Config      | pydantic-settings (reads `.env`)                |
| Auth        | Firebase Admin SDK (JWT verification)           |
| HTTP client | httpx (async, for external price APIs)          |
| Caching     | cachetools `TTLCache` (in-memory, 1000 entries) |
| Rate limits | SlowAPI (in-memory; per-user key from JWT `sub` or IP) |
| Server      | Uvicorn                                         |
| Deployment  | Render (free tier)                              |

### 3.2 Directory Layout

```
VaultTrackerAPI/
├── app/
│   ├── main.py                    # FastAPI app, lifespan, router mounts, CORS, SlowAPI
│   ├── rate_limit.py              # SlowAPI limiter, key func, 429 handler, JSON coerce helper
│   ├── config.py                  # Settings: database_url, allowed_origins,
│   │                              #   firebase_credentials_path, alpha_vantage_api_key,
│   │                              #   rate_limit_read/write/external
│   ├── database.py                # SQLAlchemy engine, SessionLocal, Base, get_db()
│   ├── dependencies.py            # get_current_user() — Firebase JWT verification + debug bypass
│   ├── models/
│   │   ├── user.py
│   │   ├── account.py
│   │   ├── asset.py
│   │   ├── transaction.py
│   │   ├── networth_snapshot.py
│   │   └── fire_profile.py        # FIREProfile: age, income, expenses, target retirement age
│   ├── schemas/
│   │   ├── account.py
│   │   ├── asset.py
│   │   ├── transaction.py         # TransactionCreate, SmartTransactionCreate,
│   │   │                          #   TransactionUpdate, EnrichedTransactionResponse
│   │   ├── dashboard.py
│   │   ├── networth.py
│   │   ├── analytics.py
│   │   ├── price.py
│   │   ├── fire.py                # FIREProfileInput/Response, FIREProjectionResponse,
│   │   │                          #   FIREAllocation, FIREFireTargets, projection curve
│   │   └── user.py
│   ├── routers/
│   │   ├── accounts.py
│   │   ├── assets.py
│   │   ├── transactions.py        # Standard CRUD + smart create + smart update
│   │   ├── dashboard.py           # Cache-backed
│   │   ├── networth.py            # Period aggregation (daily/weekly/monthly/all)
│   │   ├── analytics.py
│   │   ├── prices.py
│   │   ├── fire.py                # GET/PUT profile, GET projection
│   │   └── users.py
│   └── services/
│       ├── transaction_service.py # Asset + account resolution, smart_create, smart_update
│       ├── asset_sync.py          # update_asset_from_transaction, record_networth_snapshot
│       ├── dashboard_aggregate.py # aggregate_dashboard (totals, grouped holdings)
│       ├── analytics_service.py   # Allocation, gain/loss, cost basis
│       ├── fire_service.py        # FIRE math constants, compute_blended_return
│       ├── fire_projection.py     # build_fire_projection, profile_to_response
│       ├── price_service.py       # CoinGecko + Alpha Vantage
│       └── cache_service.py       # TTL cache singleton
├── requirements.txt
├── .env
└── start.sh
```

### 3.2.1 Rate limiting (VaultTrackerAPI)

The REST API uses **SlowAPI** with **in-memory** storage (`memory://`), suitable for a single worker on Render. Limits are **tiered** and configurable via environment variables (defaults in parentheses):

| Tier | Env var | Default | Scope |
| ---- | ------- | ------- | ----- |
| Read | `RATE_LIMIT_READ` | `60/minute` | GET on accounts, assets, transactions, dashboard, net worth history, analytics, FIRE profile/projection |
| Write | `RATE_LIMIT_WRITE` | `30/minute` | POST/PUT/DELETE on those resources + `DELETE /users/me/data`, `PUT /fire/profile` |
| External | `RATE_LIMIT_EXTERNAL` | `10/minute` | `POST /prices/refresh`, `GET /prices/{symbol}` |

`GET /` and `GET /health` are **exempt**. The rate-limit **key** is derived before auth runs: debug bypass token → `user:debug-user`; otherwise the JWT payload `sub` (no signature verification in the limiter); otherwise client IP (`X-Forwarded-For` aware). Full detail: [VaultTrackerAPI/Documentation/2026-04-13-rate-limiting-design.md](../VaultTrackerAPI/Documentation/2026-04-13-rate-limiting-design.md).

Successful responses may include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`; HTTP 429 includes `Retry-After` and a JSON body with `detail`.

### 3.3 Data Model

#### Entity Relationships

```
User (1) ──< Account (many)
User (1) ──< Asset (many)
User (1) ──< Transaction (many)
User (1) ──< NetWorthSnapshot (many)
User (1) ──  FIREProfile (one, auto-created on first access)
Transaction >── Asset (many-to-one)
Transaction >── Account (many-to-one)
```

All primary keys are UUID strings generated server-side. All cascade deletes flow from User downward.

#### Tables

**`users`**

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `firebase_id` | String UNIQUE | Stable Firebase UID; used as identity lookup |
| `email` | String nullable | Not yet populated |
| `created_at` | DateTime(tz) | UTC |

**`accounts`**

Financial institution holding assets (brokerage, bank, crypto exchange).

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `name` | String | Display name, e.g. "Coinbase" |
| `account_type` | String | `cryptoExchange`, `brokerage`, `bank`, `physicalWallet`, `cryptoWallet`, `realEstate`, `other` |
| `created_at` | DateTime(tz) | |

**`assets`**

A single financial holding, e.g. "Bitcoin", "AAPL", "Savings Account".

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `name` | String | |
| `symbol` | String nullable | Ticker; null for cash/real estate |
| `category` | String | `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |
| `quantity` | Float | Maintained by transaction writes |
| `current_value` | Float | `quantity × latest_price_per_unit` (mark-to-market) |
| `last_updated` | DateTime(tz) | Auto-updated on every transaction write |

**`transactions`**

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

**`networth_snapshots`**

Historical net worth data points.

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id | |
| `date` | DateTime(tz) | Timestamp of snapshot |
| `value` | Float | Sum of all asset `current_value` at this moment |

**`fire_profiles`**

Persistent FIRE (Financial Independence, Retire Early) planning inputs per user.

| Column | Type | Notes |
|---|---|---|
| `id` | String PK | UUID |
| `user_id` | String FK → users.id, UNIQUE | One profile per user |
| `current_age` | Integer | Validated 18–100 |
| `annual_income` | Float | |
| `annual_expenses` | Float | |
| `target_retirement_age` | Integer nullable | Optional goal age |
| `created_at` | DateTime(tz) | |
| `updated_at` | DateTime(tz) | Updated on every PUT |

### 3.4 Core Business Logic

#### Asset Value Tracking (Mark-to-Market)

Asset value uses the most recent `price_per_unit`, not cost-basis averaging:

```
current_value = asset.quantity × latest_price_per_unit
```

`update_asset_from_transaction()` is called on every transaction create, update, and delete:

- **Buy:** `asset.quantity += transaction.quantity`
- **Sell:** `asset.quantity -= transaction.quantity`
- After adjustment: `asset.current_value = asset.quantity × price_per_unit`

For **updates**, the old transaction effect is reversed before applying new values. For **deletes**, the effect is reversed then the row is removed.

#### Net Worth Snapshots

`record_networth_snapshot()` is called after every transaction mutation. It sums `current_value` across all user assets and appends a new `NetWorthSnapshot` row. Snapshots are append-only and grow with every write.

#### Cash & Real Estate Encoding

For Cash and Real Estate assets, the client sets `quantity = dollar_amount` and `price_per_unit = 1.0`. This makes the backend formula `current_value = quantity × 1.0 = dollar_amount`, tracking a running dollar balance without a price feed. This convention must stay consistent across all clients and the backend.

#### FIRE Projection

`fire_service.py` defines the default asset return assumptions and inflation constant:

| Constant | Value |
|---|---|
| `DEFAULT_RETURNS["crypto"]` | 10% |
| `DEFAULT_RETURNS["stocks"]` | 8% |
| `DEFAULT_RETURNS["realEstate"]` | 5% |
| `DEFAULT_RETURNS["retirement"]` | 7% |
| `DEFAULT_RETURNS["cash"]` | 2% |
| `DEFAULT_INFLATION` | 3% |
| `FIRE_MULTIPLIER` | 25× (4% safe withdrawal rate) |
| `PROJECTION_YEARS` | 30 |

`compute_blended_return()` weights each category's return by its share of current net worth.

`build_fire_projection()` (in `fire_projection.py`) runs a year-by-year compound simulation using the blended real return and the user's annual savings (`annual_income - annual_expenses`). It returns:
- `status`: `"reachable"` / `"beyond_horizon"` / `"unreachable"`
- `fireTargets`: lean/base/fat FIRE targets (25×/30×/35× expenses)
- `projectionCurve`: list of `{year, netWorth}` data points
- `monthlyBreakdown`: monthly savings and investment growth breakdown
- `goalAssessment`: contextual commentary on feasibility

The `FIREProfile` is auto-created with sensible defaults on the first `GET /api/v1/fire/profile` if none exists.

#### Asset Resolution (Smart Transaction)

The `TransactionService.smart_create()` method handles all server-side resolution:

1. **Account resolution:** Find an existing account by `(user_id, name)`. Create one if not found.
2. **Asset resolution:**
   - For `crypto`, `stocks`, `retirement`: match by `(user_id, symbol)`.
   - For `cash`, `realEstate`: match by `(user_id, name, category)`.
   - Create the asset if no match.
3. **Create transaction** with resolved `asset_id` and `account_id`.
4. **Update asset value** and **record net worth snapshot**.
5. **Invalidate user cache.**

### 3.5 Authentication

Every protected route uses `Depends(get_current_user)` from `app/dependencies.py`.

**Production flow:**
1. Client sends `Authorization: Bearer <firebase_jwt>`.
2. `firebase_auth.verify_id_token(token)` verifies the JWT using Firebase Admin SDK.
3. The stable `uid` from the decoded token is used as `firebase_id`.
4. The matching `User` row is returned, or auto-created on first login.

**Debug bypass (local only):**
- Enabled when `DEBUG_AUTH_ENABLED=true`.
- Token value `"vaulttracker-debug-user"` maps to `firebase_id = "debug-user"`.
- Must be `false` in any deployed environment.

All data is user-scoped — every query filters by `user_id`.

### 3.6 API Endpoints

All routes share the prefix `/api/v1`. All except `GET /` and `GET /health` require `Authorization: Bearer <token>`.

**Health**

| Method | Path | Auth |
|---|---|---|
| GET | `/` | No |
| GET | `/health` | No |

**Accounts — `/api/v1/accounts`**

| Method | Path | Notes |
|---|---|---|
| GET | `/accounts` | All accounts for user |
| POST | `/accounts` | Create: `{ name, account_type }` |
| GET | `/accounts/{id}` | 404 if not owned |
| PUT | `/accounts/{id}` | Partial update via `exclude_unset` |
| DELETE | `/accounts/{id}` | Cascades to transactions |

**Assets — `/api/v1/assets`**

| Method | Path | Notes |
|---|---|---|
| GET | `/assets?category=` | Optional category filter |
| POST | `/assets` | Create: `{ name, symbol?, category, quantity=0, current_value=0 }` |
| GET | `/assets/{id}` | 404 if not owned |

**Transactions — `/api/v1/transactions`**

| Method | Path | Notes |
|---|---|---|
| GET | `/transactions` | Returns `EnrichedTransactionResponse` with inline asset + account |
| POST | `/transactions` | Legacy: requires pre-resolved `asset_id` + `account_id` |
| POST | `/transactions/smart` | **Preferred:** auto-resolves asset + account from names |
| GET | `/transactions/{id}` | |
| PUT | `/transactions/{id}` | Legacy update: reverses old effect, applies new, records snapshot |
| PUT | `/transactions/{id}/smart` | Smart update: re-resolves account + asset from names, then applies |
| DELETE | `/transactions/{id}` | Reverses asset effect, records snapshot |

**Dashboard — `/api/v1/dashboard`**

| Method | Path | Notes |
|---|---|---|
| GET | `/dashboard` | Aggregated totals + grouped holdings; cache-backed (5 min TTL) |

Response:
```json
{
  "totalNetWorth": 150000.0,
  "categoryTotals": { "crypto": 50000.0, "stocks": 80000.0, "cash": 20000.0, "realEstate": 0.0, "retirement": 0.0 },
  "groupedHoldings": {
    "crypto": [{ "id", "name", "symbol", "quantity", "current_value" }],
    ...
  }
}
```

**Net Worth History — `/api/v1/networth`**

| Method | Path | Notes |
|---|---|---|
| GET | `/networth/history?period=daily\|weekly\|monthly\|all` | Period-aggregated snapshots (last snapshot per period); `all` returns every snapshot unfiltered |

**FIRE — `/api/v1/fire`**

| Method | Path | Notes |
|---|---|---|
| GET | `/fire/profile` | Get user FIRE profile; auto-creates with defaults if none exists |
| PUT | `/fire/profile` | Upsert FIRE profile inputs (`currentAge`, `annualIncome`, `annualExpenses`, `targetRetirementAge?`) |
| GET | `/fire/projection` | Run FIRE projection from saved profile; returns curve, targets, monthly breakdown, goal assessment |

**Analytics — `/api/v1/analytics`**

| Method | Path | Notes |
|---|---|---|
| GET | `/analytics` | Allocation %, gain/loss, cost basis, current value; cache-backed (5 min TTL) |

Response:
```json
{
  "allocation": {
    "crypto": { "value": 50000.0, "percentage": 33.3 },
    ...
  },
  "performance": {
    "totalGainLoss": 12000.0,
    "totalGainLossPercent": 8.7,
    "costBasis": 138000.0,
    "currentValue": 150000.0
  }
}
```

**Prices — `/api/v1/prices`**

| Method | Path | Notes |
|---|---|---|
| POST | `/prices/refresh` | Refreshes all user assets with live prices from CoinGecko/Alpha Vantage |
| GET | `/prices/{symbol}` | Single symbol price lookup |

**Users — `/api/v1/users`**

| Method | Path | Notes |
|---|---|---|
| DELETE | `/users/me/data` | Wipes all user financial data; preserves user row |

### 3.7 Caching Strategy

In-memory `TTLCache` (singleton `CacheService`). Cache keys are namespaced by `user_id` to prevent cross-user leakage.

| Endpoint | TTL | Invalidated By |
|---|---|---|
| Dashboard | 5 min | Any transaction write or price refresh |
| Analytics | 5 min | Any transaction write or price refresh |
| Net worth history | 5 min | Any transaction write |
| FIRE projection | — | Not cached server-side; computed on each request from saved profile |
| Price lookup | 15 min (crypto), 60 min (stocks) | Rate-limit-driven |

Cache is invalidated via `cache.invalidate_user(user_id)` after any data mutation in `TransactionService` and `PriceService`.

### 3.8 External Price APIs

**CoinGecko** (crypto, free tier):
- Endpoint: `GET /simple/price?ids={coin_id}&vs_currencies=usd`
- Symbol → ID mapping maintained in `price_service.py` (BTC→bitcoin, ETH→ethereum, etc.)

**Alpha Vantage** (stocks, API key required):
- Endpoint: `GLOBAL_QUOTE?symbol={symbol}&apikey={key}`
- Parses `"05. price"` from response

Both are async (`httpx.AsyncClient`). Errors per-asset are captured and returned in the refresh response rather than aborting the entire batch.

---

## 4. iOS App

### 4.1 Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Charts | Swift Charts |
| Networking | URLSession + async/await |
| Auth | Firebase Auth (Google Sign-In) |
| Local persistence | None (all data is remote) |
| Deployment | TestFlight / App Store |

### 4.2 Architecture

```
VaultTrackerApp (entry point)
│
├── AuthManager (@MainActor, ObservableObject)
│       Firebase auth state machine
│
├── DataService (@MainActor, DataServiceProtocol)
│       Business facade — converts API types to domain models
│       │
│       └── APIService (APIServiceProtocol)
│               URLSession wrapper, JWT auth, 401 retry
│               │
│               └── AuthTokenProvider (actor)
│                       Firebase JWT token fetching
│
├── DesignSystem/
│       VTColors, VTFonts, VTTypography, VTComponents
│       (buttons, chips, surfaces — shared across all views)
│
└── Views (SwiftUI)
        │
        └── ViewModels (@MainActor, ObservableObject)
                Depend on DataServiceProtocol (not concrete class)
                Drives SwiftUI view state
```

Protocol-based dependency injection at every layer enables unit testing with mock implementations.

### 4.3 Authentication Flow

```
App launch
  → FirebaseApp.configure()
  → AuthManager subscribes to Auth.auth().addStateDidChangeListener
      .authenticating → LoadingView
      .authenticated  → TabView (Home + Profile + Analytics)
      .unauthenticated → LoginView

Login tap
  → GIDSignIn.signIn() → GoogleAuthProvider.credential
  → Auth.auth().signIn(with: credential)
  → state becomes .authenticated

API request
  → AuthTokenProvider.getToken()
  → URLRequest with Authorization: Bearer {token}
  → 401 → forceRefresh → retry
  → Second 401 → post .authenticationRequired notification
  → AuthManager.signOut()
```

**Debug bypass:** `signInDebug()` sets `AuthTokenProvider.isDebugSession = true`. All API requests send `"vaulttracker-debug-user"` as the bearer token. Requires `DEBUG_AUTH_ENABLED=true` on the backend.

### 4.4 Networking Layer

**`APIService.swift`**
- Singleton `APIService.shared`
- Conforms to `APIServiceProtocol` (injectable for tests)
- Every request: fetch token → build `URLRequest` with `Authorization: Bearer` → decode JSON
- 401 handling: force refresh Firebase token → retry once → post `.authenticationRequired` on second 401
- Custom date decoding: handles both `+00:00`/`Z` timezone-aware and legacy naive ISO 8601

**`APIConfiguration.swift`**

| Constant | Path |
|---|---|
| `dashboard` | `GET /api/v1/dashboard` |
| `transactions` | `GET/POST /api/v1/transactions` |
| `smartTransaction` | `POST /api/v1/transactions/smart` |
| `transaction(id:)` | `GET/PUT/DELETE /api/v1/transactions/{id}` |
| `accounts` | `GET/POST /api/v1/accounts` |
| `account(id:)` | `GET/PUT/DELETE /api/v1/accounts/{id}` |
| `assets` | `GET/POST /api/v1/assets` |
| `asset(id:)` | `GET /api/v1/assets/{id}` |
| `networthHistory` | `GET /api/v1/networth/history` |
| `analytics` | `GET /api/v1/analytics` |
| `priceRefresh` | `POST /api/v1/prices/refresh` |
| `clearUserData` | `DELETE /api/v1/users/me/data` |

Base URL: `https://vaulttracker-api.onrender.com` (production). Switched via `APIConfiguration.environment`.

### 4.5 Data Layer

**`DataService.swift`** (`@MainActor`, singleton `DataService.shared`)

Delegates all I/O to `APIService`. Converts API response types (`APIXxxResponse`) to domain models via mapper enums:

| Mapper | Converts |
|---|---|
| `DashboardMapper.toViewState` | `APIDashboardResponse` → `HomeViewState` |
| `AssetMapper.toDomain` | `APIAssetResponse` → `Asset` |
| `AccountMapper.toDomain` | Maps `account_type` strings to `AccountType` enum |
| `TransactionMapper.toDomain` | `APIEnrichedTransactionResponse` → `Transaction` |

`fetchAllTransactions()` uses the enriched endpoint — single fetch, no client-side join required.

### 4.6 Domain Models

| Model | Key Fields |
|---|---|
| `Asset` | `id`, `name`, `category` (AssetCategory), `symbol`, `quantity`, `price`, `currentValue`, `lastUpdated` |
| `Transaction` | `id`, `transactionType`, `quantity`, `pricePerUnit`, `date`, `name`, `symbol`, `category`, `account` |
| `Account` | `id`, `name`, `accountType` (AccountType), `creationDate` |
| `NetWorthSnapshot` | `date: Date`, `value: Double` |

**`AssetCategory`** enum: `.crypto`, `.stocks`, `.realEstate`, `.cash`, `.retirement`

**`AccountType`** enum: `.bank`, `.brokerage`, `.cryptoExchange`, `.physicalWallet`, `.cryptoWallet`, `.realEstate`, `.other`

### 4.7 Home Screen

**`HomeViewModel`** (`@MainActor`, `ObservableObject`):
- `viewState: HomeViewState` — totals, grouped holdings, filter selection, loading/error state
- `snapshots: [NetWorthSnapshot]` — data for the chart
- `loadData()` — fetches dashboard + net worth history
- `onSave(transaction:)` — calls `dataService.createSmartTransaction()` → reloads dashboard
- `refreshPrices()` — calls `dataService.refreshPrices()` → reloads dashboard
- `selectFilter(category:)` — filters displayed holdings
- `clearData()` — calls `DELETE /api/v1/users/me/data`

**`HomeView`**: ScrollView with error banner, filter chip bar, `NetWorthChartView` (Swift Charts line + area, CatmullRom), net worth total, proportional category bar, expandable category sections, toolbar ("+" add transaction, "Refresh Prices", "Clear Data").

### 4.8 Add Transaction Flow

**`AddAssetFormViewModel`** (`@MainActor`, `ObservableObject`):
- Form state: `transactionType`, `accountName`, `accountType`, `name`, `symbol`, `selectedCategory`, `quantity`, `pricePerUnit`, `date`
- `save()` builds `APISmartTransactionCreateRequest` and delegates to `DataService`
- Cash/Real Estate special case: `quantity = dollarAmount`, `pricePerUnit = 1.0`
- Symbol field hidden for `.cash` and `.realEstate`
- Account type validated against selected asset category

### 4.9 Analytics Tab

**`AnalyticsViewModel`** (`@MainActor`, `ObservableObject`):
- Calls `GET /api/v1/analytics`
- Maps to view state: allocation percentages + performance summary

**`AnalyticsView`**: Allocation pie/bar chart + performance cards (gain/loss, cost basis, current value).

---

## 5. Web App

### 5.1 Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 15+ (App Router) |
| Language | TypeScript 5.x |
| Styling | Tailwind CSS 4.x |
| Components | shadcn/ui (via `@base-ui/react`) |
| Server state | TanStack React Query 5.x |
| Charts | Recharts 3.x |
| Tables | TanStack Table 8.x |
| Forms | React Hook Form + Zod |
| Auth | Firebase Auth (Web SDK) |
| Error monitoring | Sentry (`@sentry/nextjs`) |
| E2E testing | Playwright |
| Deployment | Vercel (free tier) |

### 5.2 Directory Structure

```
vaulttracker-web/
├── src/
│   ├── app/
│   │   ├── layout.tsx                  # Root layout: providers, fonts, metadata, Sentry
│   │   ├── error.tsx                   # Root error boundary
│   │   ├── global-error.tsx            # Layout-level render errors
│   │   ├── page.tsx                    # / → redirect based on auth state
│   │   ├── login/page.tsx              # Google Sign-In
│   │   └── (authenticated)/            # Route group with auth guard
│   │       ├── layout.tsx              # Auth check + app shell
│   │       ├── error.tsx               # Segment error boundary
│   │       ├── dashboard/page.tsx
│   │       ├── analytics/page.tsx
│   │       ├── transactions/page.tsx
│   │       ├── accounts/page.tsx
│   │       ├── fire/page.tsx           # FIRE calculator (inputs + projection)
│   │       └── profile/page.tsx
│   ├── components/
│   │   ├── ui/                         # shadcn/ui components
│   │   ├── layout/                     # Sidebar, mobile nav, app shell
│   │   ├── dashboard/
│   │   │   ├── holdings-grid.tsx       # Category holdings grid
│   │   │   └── asset-detail-dialog.tsx # Read-only asset modal (holdings, recent txns)
│   │   ├── analytics/                  # Bento grid: allocation donut, performance, price lookup
│   │   ├── transactions/               # Table, add/edit form dialog
│   │   ├── accounts/                   # Account cards, add/edit form
│   │   └── fire/                       # FIRE inputs form, projection chart, targets
│   ├── lib/
│   │   ├── api-client.ts               # Fetch wrapper: JWT header, 401 retry
│   │   ├── firebase.ts                 # Firebase app init
│   │   ├── auth-debug.ts               # Build-time debug token constants (dev only)
│   │   ├── logger.ts                   # Logging facade (console dev / Sentry prod)
│   │   ├── format.ts                   # Date and number formatting helpers
│   │   ├── account-types.ts            # AccountType enum + category validation helpers
│   │   ├── transaction-schema.ts       # Zod schema for transaction form validation
│   │   ├── networth-change.ts          # Net worth change calculations
│   │   ├── fire/
│   │   │   └── fire-input-schema.ts    # Zod schema for FIRE profile PUT validation
│   │   └── queries/                    # React Query hooks per domain
│   ├── contexts/
│   │   ├── auth-context.tsx            # Firebase auth state + token management
│   │   └── api-client-context.tsx      # ApiClientProvider — injects configured ApiClient
│   └── types/
│       └── api.ts                      # TypeScript types mirroring all backend schemas
└── ...config files
```

### 5.3 Pages

| Route | Page | Data |
|---|---|---|
| `/` | Redirect (auth state switch) | — |
| `/login` | Google Sign-In | Firebase Auth |
| `/dashboard` | Net worth, chart, categories, holdings | `GET /dashboard` + `GET /networth/history` |
| `/analytics` | Allocation bento grid, gain/loss, price lookup | `GET /analytics` |
| `/transactions` | Sortable table + add/edit/delete | `GET /transactions` (enriched) + `POST /transactions/smart` + `PUT /transactions/{id}/smart` |
| `/accounts` | Account CRUD | `GET /accounts` + CRUD endpoints |
| `/fire` | FIRE calculator: profile inputs + projection curve | `GET /fire/profile` + `PUT /fire/profile` + `GET /fire/projection` |
| `/profile` | User info, sign out, theme toggle, delete all data | Firebase Auth + `DELETE /users/me/data` |

### 5.4 Auth Guard Pattern

Next.js route group `(authenticated)/layout.tsx` checks auth state before rendering any child page. Unauthenticated users are redirected to `/login`. Loading state shows a skeleton.

### 5.5 API Client (`lib/api-client.ts`)

Single class wrapping `fetch` with:
- `Authorization: Bearer {token}` header on every request
- 401 handling: force-refresh Firebase token → retry once
- Second 401: call `onUnauthorized()` (signs out) → throw
- Methods: `get<T>()`, `post<T>()`, `put<T>()`, `delete()`

### 5.6 React Query Hooks

Each domain has its own hook file in `src/lib/queries/`. Mutations invalidate related queries on success:

| Hook | Endpoint | Notes |
|---|---|---|
| `useDashboard()` | `GET /dashboard` | Invalidated by transaction + asset mutations |
| `useAnalytics()` | `GET /analytics` | Invalidated by price refresh + transaction mutations |
| `useNetworth(period?)` | `GET /networth/history?period=...` | Accepts `daily\|weekly\|monthly\|all` |
| `useTransactions()` | `GET /transactions` | `useTransactionMutations` handles add/edit/delete |
| `useAccounts()` | `GET /accounts` | `useAccountMutations` handles add/edit/delete |
| `useAssets()` | `GET /assets` | Read-only |
| `useFire()` | `GET /fire/profile` + `PUT /fire/profile` | Also exposes `useFireProjection()` for `GET /fire/projection` |
| `usePrices()` | `GET /prices/{symbol}` | Single-symbol lookup mutation |
| `useUser()` | `DELETE /users/me/data` | Clear all financial data mutation |

Key invalidation chains:
- `useCreateTransaction()` / `useUpdateTransaction()` / `useDeleteTransaction()` → invalidates `dashboard`, `transactions`, `networth`, `analytics`, `assets`
- `useRefreshPrices()` → invalidates `dashboard`, `analytics`
- `useDeleteAccount()` → invalidates `accounts`

### 5.7 Add Transaction Form

Fields driven by `POST /api/v1/transactions/smart`. Validation via Zod. Category-dependent field visibility:

- Symbol input: hidden for `cash` and `realEstate`
- Quantity label: "Amount ($)" for `cash`/`realEstate`, "Quantity" for others
- Price per unit: hidden for `cash`/`realEstate` (hardcoded to `1.0`)
- Account type: filtered to valid types for the selected category

### 5.8 Transaction Table

TanStack Table with sort, filter (by category, type, account, asset name search), and client-side pagination (20 rows/page). Supports edit, delete with confirmation, and CSV export.

### 5.9 Responsive Layout

- **Desktop (>1024px):** Fixed sidebar navigation + main content area
- **Mobile (<768px):** Full-width content + bottom tab bar

Dark-only theme enforced via Tailwind `darkMode: "class"`. No light mode toggle — all pages render in dark mode.

### 5.10 FIRE Calculator

**`/fire` page** — Financial Independence, Retire Early planning tool.

**Inputs (saved to backend via `PUT /fire/profile`):**
- `currentAge` — validated 18–100
- `annualIncome`
- `annualExpenses`
- `targetRetirementAge` (optional)

**Projection (`GET /fire/projection`)** — Returns:
- `status`: `"reachable"` | `"beyond_horizon"` | `"unreachable"`
- `fireTargets`: lean (25×), base (30×), fat (35×) annual expenses
- `projectionCurve`: year-by-year `{year, netWorth}` data points (rendered as AreaChart)
- `monthlyBreakdown`: savings vs. investment growth split per month
- `goalAssessment`: contextual commentary

`useFire()` from `src/lib/queries/use-fire.ts` handles both the profile GET/PUT and the projection query. Profile updates immediately refetch the projection.

### 5.11 Error Handling

**Sentry** is integrated via `@sentry/nextjs`. Errors in server components are captured at `app/error.tsx` (segment level) and `app/global-error.tsx` (root layout level). `src/lib/logger.ts` provides a unified facade: `console.*` in development, Sentry in production.

---

## 6. Cross-Cutting Concerns

### 6.1 Identity & Auth

| Client | Auth Method | Token Type |
|---|---|---|
| iOS | Firebase SDK (Google Sign-In) | Firebase ID token (JWT) |
| Web | Firebase Web SDK (Google Sign-In) | Firebase ID token (JWT) |
| Backend | Firebase Admin SDK `verify_id_token()` | Verifies and extracts `uid` |

All three clients share the same Firebase project. A single Google account grants access to the same data on both iOS and web.

### 6.2 Category String Conventions

Category strings are camelCase and must match exactly across all clients and the backend:

| Category | Backend string | iOS enum | Web string |
|---|---|---|---|
| Cryptocurrency | `crypto` | `.crypto` | `"crypto"` |
| Stocks/ETFs | `stocks` | `.stocks` | `"stocks"` |
| Cash | `cash` | `.cash` | `"cash"` |
| Real Estate | `realEstate` | `.realEstate` | `"realEstate"` |
| Retirement | `retirement` | `.retirement` | `"retirement"` |

`DashboardMapper` accepts both `"real_estate"` and `"realEstate"` to guard against inconsistencies.

### 6.3 Error Handling

**Backend:** FastAPI raises `HTTPException` with structured JSON error bodies. 422 responses include per-field validation messages (Pydantic).

**iOS (`APIError.swift`):**

| Case | Trigger |
|---|---|
| `.notAuthenticated` | No Firebase user |
| `.unauthorized` | 401 after token refresh |
| `.forbidden` | 403 |
| `.notFound` | 404 |
| `.validationError([String])` | 422 — extracts FastAPI field messages |
| `.serverError(Int)` | 5xx |
| `.networkError(Error)` | Transport failure |
| `.decodingError(Error)` | JSON decode failure |
| `.unknown(Int)` | Any other status code |

**Web:** `ApiClient` throws typed `ApiError` instances. React Query surfaces errors via `isError` / `error` states. Each page component renders an error state.

### 6.4 Data Consistency Invariants

1. **Asset quantity is the source of truth** for position size. Never edit it directly; only transaction writes update it.
2. **`current_value = quantity × price_per_unit`** (mark-to-market). This is recomputed on every transaction write and price refresh.
3. **Cash/Real Estate:** `quantity = dollar_amount`, `price_per_unit = 1.0`. This convention is required for the mark-to-market formula to produce the correct dollar value.
4. **Snapshot append-only:** Never delete or modify snapshot rows — they are the historical record for charts.
5. **Asset identity:** Crypto/stocks/retirement deduplicated by symbol. Cash/real estate deduplicated by (name, category). This prevents duplicate asset rows for repeated buys of the same holding.

---

## 7. Deployment

| Component | Platform | Notes |
|---|---|---|
| Backend API | Render (free tier) | URL: `https://vaulttracker-api.onrender.com` |
| Database | Neon (PostgreSQL free tier) | Connection via `DATABASE_URL` env var |
| Web App | Vercel (free tier) | Connected to GitHub repo |
| iOS App | TestFlight / App Store | — |

### Backend Environment Variables

```
DATABASE_URL=postgresql://user:pass@host:5432/vaulttracker
FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json
ALPHA_VANTAGE_API_KEY=...
ALLOWED_ORIGINS=http://localhost:3000,https://vaulttracker.vercel.app
DEBUG_AUTH_ENABLED=false
```

### Web App Environment Variables

```
NEXT_PUBLIC_API_URL=https://vaulttracker-api.onrender.com
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
```

---

## 8. Known Limitations & Future Work

| Area | Current State | Future Improvement |
|---|---|---|
| Net worth snapshots | Append-only, one per transaction write; no pruning | Implement downsampling / retention policy for old snapshots |
| Asset valuation | Mark-to-market (latest price re-prices entire position) | Cost-basis / average-price tracking |
| Pagination | All user records returned in a single response | Add cursor-based pagination for transactions |
| Caching | In-memory TTL cache; resets on server restart | Migrate to Redis for persistent cache across instances |
| Per-category trends | Analytics returns overall net worth history only | Add per-category snapshot table for category-level trend charts |
| CoinGecko symbol map | Maintained manually in `price_service.py` | Use CoinGecko search endpoint to resolve symbols dynamically |
| Alpha Vantage rate limits | Free tier: 25 requests/day | Add request queuing and per-symbol cache TTLs |
| Offline mode | No local persistence; app unusable without network | Add SwiftData/IndexedDB read-only cache for last known state |
| Account type validation | Client-side only (iOS: `isAccountTypeValidForAssetCategory`) | Enforce server-side in smart transaction endpoint |
| FIRE on iOS | FIRE calculator not yet in the iOS app | Add FIRE profile + projection screens to iOS |
| FIRE return rates | Hardcoded default returns per category | Allow users to override expected returns per asset class |
| FIRE projection cache | Projection recomputed on every request | Cache projection result keyed by profile hash; invalidate on profile PUT |
