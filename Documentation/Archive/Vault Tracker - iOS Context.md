---
tags:
  - vaultTracker
  - swift
  - ios
title: Vault Tracker - iOS Context
---

# VaultTracker — Technical Overview

> Intended audience: AI agents and developers who need fast, accurate context before working in this codebase.

---

## What VaultTracker Is

A personal net-worth tracker iOS app. Users log financial transactions (buy/sell) across five asset categories — **Crypto, Stocks/ETFs, Cash, Real Estate, Retirement** — and see a live net-worth total with a historical chart. All data lives on a local FastAPI backend; the iOS client has no local persistence.

---

## High-Level Architecture

```
┌─────────────────────────────────────────┐
│  iOS App (Swift / SwiftUI)              │
│                                         │
│  AuthManager (Firebase)                 │
│       │                                 │
│  DataService ──── APIService            │
│       │               │                 │
│  ViewModels       URLSession            │
│       │               │                 │
│   SwiftUI Views   HTTP Bearer JWT       │
└───────────────────────┬─────────────────┘
                        │  REST JSON /api/v1
┌───────────────────────▼─────────────────┐
│  VaultTrackerAPI (Python / FastAPI)     │
│                                         │
│  dependencies.py  ← Firebase JWT auth  │
│  routers/         ← CRUD endpoints     │
│  models/          ← SQLAlchemy ORM     │
│  schemas/         ← Pydantic I/O       │
│  SQLite (vaulttracker.db)              │
└─────────────────────────────────────────┘
```

---

## iOS App

### Entry Point — `VaultTrackerApp.swift`

`@main` App struct. Owns a single `@StateObject var authManager`. On launch, switches between three root views based on `authManager.authenticationState`:

| State | View shown |
|-------|-----------|
| `.authenticating` | `LoadingView` |
| `.authenticated` | `TabView` (Home + Profile) |
| `.unauthenticated` | `LoginView` |

`FirebaseApp.configure()` is called in `init()`.

---

### Authentication — `AuthManager.swift`

- `@MainActor final class`, `ObservableObject`
- Observes Firebase `Auth.auth().addStateDidChangeListener` to track `AuthenticationState`.
- **Sign in:** `signInWithGoogle()` via `GIDSignIn.sharedInstance.signIn` → Firebase `GoogleAuthProvider.credential`.
- **Sign out:** `try Auth.auth().signOut()`.
- **Auto sign-out on session expiry:** Listens for `Notification.Name.authenticationRequired` (posted by `APIService` when a 401 persists after token refresh) and calls `signOut()`.
- **DEBUG bypass:** `signInDebug()` sets `AuthTokenProvider.isDebugSession = true`, bypassing Firebase entirely. Matches the backend's `DEBUG_AUTH_ENABLED=true` + `"vaulttracker-debug-user"` token.

---

### Token Management — `AuthTokenProvider.swift`

- `actor` (thread-safe). Singleton: `AuthTokenProvider.shared`.
- `getToken(forceRefresh: Bool)` wraps `user.getIDTokenForcingRefresh(_:)` in a `withCheckedThrowingContinuation`.
- In DEBUG mode, returns hardcoded `"vaulttracker-debug-user"` string when `isDebugSession == true`.

---

### Networking — `APIService.swift`

- `final class`, singleton `APIService.shared`, conforms to `APIServiceProtocol`.
- Uses `URLSession.shared` directly (not the legacy `NetworkService`).
- **Auth:** Every request gets `Authorization: Bearer <token>` via `AuthTokenProvider`.
- **401 retry:** On 401, force-refreshes the token and retries once. If the retry is also 401, posts `.authenticationRequired` notification and throws `.unauthorized`.
- **Date decoding:** Custom strategy handles both timezone-aware ISO 8601 (`+00:00` / `Z`) and legacy naive datetimes (treated as UTC).
- **Error mapping:** All errors are typed as `APIError` (see below).

**Endpoints (`APIConfiguration.swift`):**

| Constant | Path |
|----------|------|
| `dashboard` | `GET /api/v1/dashboard` |
| `accounts` | `GET/POST /api/v1/accounts` |
| `account(id:)` | `GET/PUT/DELETE /api/v1/accounts/{id}` |
| `assets` | `GET/POST /api/v1/assets` |
| `asset(id:)` | `GET /api/v1/assets/{id}` |
| `transactions` | `GET/POST /api/v1/transactions` |
| `transaction(id:)` | `GET/PUT/DELETE /api/v1/transactions/{id}` |
| `networthHistory` | `GET /api/v1/networth/history` |
| `clearUserData` | `DELETE /api/v1/users/me/data` |

Base URL reads `API_HOST` from the Xcode scheme's environment variables (defaults to `localhost:8000`). Set `API_HOST=192.168.x.x:8000` for physical device builds.

---

### Data Layer — `DataService.swift` + `DataServiceProtocol.swift`

- `@MainActor final class DataService`, singleton `DataService.shared`.
- Conforms to `DataServiceProtocol` — ViewModels depend on the protocol, not the class, enabling mock injection in tests.
- Delegates all I/O to `APIService`. Converts API response types (`APIXxxResponse`) to domain models (`Asset`, `Account`, `Transaction`) via mapper enums.

**`fetchAllTransactions()`** fetches transactions, assets, and accounts in parallel (`async let`) then joins them to build fully-denormalised `Transaction` domain objects.

**`createTransaction()`** fetches the newly created asset and all accounts in parallel after creation to resolve the domain model.

**Net worth history** is fetched from the server; the app no longer manages snapshots locally.

---

### API Error Handling — `APIError.swift`

`enum APIError: LocalizedError` with cases:

| Case | Trigger |
|------|---------|
| `.notAuthenticated` | No Firebase user when building request |
| `.unauthorized` | 401 after token refresh |
| `.forbidden` | 403 |
| `.notFound` | 404 |
| `.validationError([String])` | 422 — extracts FastAPI field messages |
| `.serverError(Int)` | 5xx |
| `.networkError(Error)` | Transport failure |
| `.decodingError(Error)` | JSON decode failure |
| `.unknown(Int)` | Any other status code |

All ViewModels catch `APIError` and surface `error.errorDescription` in `viewState.errorMessage`.

---

### Domain Models

**`Asset`** — `struct`, `Sendable`, `Identifiable`. Fields: `id`, `name`, `category`, `symbol`, `quantity`, `price`, `currentValue`, `notes`, `lastUpdated`.

**`AssetCategory`** — `enum`, `CaseIterable`: `.crypto`, `.stocks`, `.realEstate`, `.cash`, `.retirement`. Raw values are display strings (e.g. `"Stocks/ETFs"`). Backend uses camelCase keys (`"realEstate"`, `"stocks"`).

**`Transaction`** — `struct`, `Sendable`, `Identifiable`. Fields: `id`, `transactionType`, `quantity`, `pricePerUnit`, `date`, `name`, `symbol`, `category`, `account`.

**`TransactionType`** — `enum`: `.buy`, `.sell`. Raw value lowercased for API.

**`Account`** — `struct`, `Sendable`, `Identifiable`. Fields: `id`, `name`, `accountType`, `creationDate`.

**`AccountType`** — `enum`: `.bank`, `.brokerage`, `.cryptoExchange`, `.physicalWallet`, `.cryptoWallet`, `.realEstate`, `.other`. Mapped to snake_case for API (`"crypto_exchange"`, `"bank"`, etc.).

**`NetWorthSnapshot`** — `struct`: `date: Date`, `value: Double`.

---

### API Response / Mapper Layer

Mappers in `API/Mappers/` convert between `APIXxxResponse` types and domain models:

| Mapper | Function |
|--------|----------|
| `DashboardMapper.toViewState(_:)` | `APIDashboardResponse` → `HomeViewState` |
| `AssetMapper.toDomain(_:)` | `[APIAssetResponse]` / `APIAssetResponse` → `[Asset]` / `Asset` |
| `AccountMapper.toDomain(_:)` | Maps `account_type` strings to `AccountType` enum |
| `TransactionMapper.toDomain(_:assetsByID:accountsByID:)` | Joins transaction + asset + account lookups |

`DashboardMapper` accepts both `"real_estate"` and `"realEstate"` keys to guard against future backend changes.

---

### Home Screen

**`HomeViewWrapper.swift`** — thin wrapper that injects a `HomeViewModel` into `HomeView` as an `@EnvironmentObject`.

**`HomeViewModel.swift`** — `@MainActor final class`, `ObservableObject`:
- `viewState: HomeViewState` — all display data (totals, grouped holdings, filter, loading/error state).
- `snapshots: [NetWorthSnapshot]` — chart data.
- `loadData()` — fetches dashboard, maps to `viewState`, fetches net worth history.
- `onSave(transaction:)` — resolves or creates an asset record server-side (matches by symbol for crypto/stocks/retirement, by name for cash/real estate), then creates the transaction, then reloads.
- `selectFilter(category:)` — filters `filteredAssets` to a single category's holdings.
- `clearData()` — calls `DELETE /api/v1/users/me/data`.

**`HomeView.swift`** — `ScrollView` with:
1. Error banner (dismissible).
2. Horizontal filter chip bar (All + 5 categories).
3. `NetWorthChartView` (Swift Charts line + area).
4. Net worth total text.
5. Proportional color bar breakdown (when net worth > 0).
6. Expandable category sections (all categories) or flat filtered list.
7. Toolbar: "Clear Data" (destructive, requires confirmation dialog) + "+" add transaction.
8. `.task` triggers `loadData()` on appear; `.refreshable` on pull-to-refresh.
9. Loading overlay (`ProgressView`).

**`NetWorthChartView.swift`** — Swift Charts `LineMark` + `AreaMark` (CatmullRom interpolation), axes hidden, 200pt height.

---

### Add Transaction Flow

**`AddAssetModalView.swift`** — sheet presented from `HomeView`. Hosts `AddAssetFormViewModel`.

**`AddAssetFormViewModel.swift`** — `@MainActor final class`, `ObservableObject`:
- Form fields: `transactionType`, `accountName`, `accountType`, `name`, `symbol`, `selectedCategory`, `quantity`, `pricePerUnit`, `date`.
- **Cash / Real Estate special case:** `quantity = dollarAmount`, `pricePerUnit = 1.0`. This makes the backend formula `current_value = quantity * price_per_unit` track a running dollar balance.
- **Symbol field:** Hidden for `.cash` and `.realEstate`; required for other categories.
- **Account resolution:** `getOrCreateAccount()` fetches all accounts first and reuses an existing server UUID by name match before creating a new one.
- `save()` returns a `Transaction` value object; caller (`HomeViewModel.onSave`) handles the API write.
- `isAccountTypeValidForAssetCategory` validates that account types are compatible with asset categories.

---

### Profile Screen

**`ProfileView.swift`** — minimal: displays `authManager.user?.displayName`, "Sign Out" button that calls `authManager.signOut()`.

---

### Custom UI Components

- **`CustomButtonView.swift`** — reusable styled button.
- **`CustomTextField.swift`** — reusable styled text field.
- **`Extensions.swift`** — `Double.currencyFormat()`, `Double.twoDecimalString`, and other formatting helpers used throughout views.
- **`Utilities.swift`** — `getTopViewController()` used by `AuthManager.signInWithGoogle()`.

---

## Backend — VaultTrackerAPI

**Stack:** Python, FastAPI, SQLAlchemy (sync), SQLite (`vaulttracker.db`), Pydantic v2.

### Database Models (`app/models/`)

| Model | Table | Key Fields |
|-------|-------|------------|
| `User` | `users` | `id`, `firebase_id` |
| `Account` | `accounts` | `id`, `user_id`, `name`, `account_type` |
| `Asset` | `assets` | `id`, `user_id`, `name`, `symbol`, `category`, `quantity`, `current_value`, `last_updated` |
| `Transaction` | `transactions` | `id`, `user_id`, `asset_id`, `account_id`, `transaction_type`, `quantity`, `price_per_unit`, `date` |
| `NetWorthSnapshot` | `networth_snapshots` | `id`, `user_id`, `value`, `date` |

All tables created on startup via `Base.metadata.create_all`.

### Asset Value Tracking

Asset value is **mark-to-market**, not cost-basis:

```
current_value = asset.quantity * latest_price_per_unit
```

Every transaction write (create/update/delete) calls `update_asset_from_transaction()` to adjust `quantity` and recompute `current_value`, then calls `record_networth_snapshot()` to append a `NetWorthSnapshot`.

### Authentication (`app/dependencies.py`)

`get_current_user` dependency:
1. Strips `Bearer ` prefix.
2. **Debug bypass:** If `DEBUG_AUTH_ENABLED=true` and token == `"vaulttracker-debug-user"`, uses `firebase_id = "debug-user"`.
3. Otherwise, uses the raw token as `firebase_id` (TODO: real Firebase JWT verification).
4. Auto-creates a `User` row on first login.

**Note:** Real Firebase JWT verification is not yet implemented on the backend. The token itself is currently used as the `firebase_id`. This works because Firebase issues stable UIDs, and the iOS client sends the real Firebase ID token.

### Routers (`/api/v1/...`)

| Router | Prefix | Operations |
|--------|--------|-----------|
| `dashboard` | `/dashboard` | GET — aggregated totals + grouped holdings |
| `accounts` | `/accounts` | CRUD |
| `assets` | `/assets` | CRUD (create/read; assets are also side-effected by transactions) |
| `transactions` | `/transactions` | CRUD — each write updates asset + records snapshot |
| `networth` | `/networth` | GET `/history` — all snapshots ordered by date |
| `users` | `/users` | DELETE `/me/data` — wipe all user financial data |

### Dashboard Response Structure

```json
{
  "totalNetWorth": 42000.0,
  "categoryTotals": {
    "crypto": 5000.0,
    "stocks": 20000.0,
    "cash": 10000.0,
    "realEstate": 5000.0,
    "retirement": 2000.0
  },
  "groupedHoldings": {
    "crypto": [{ "id": "...", "name": "Bitcoin", "symbol": "BTC", "quantity": 0.1, "current_value": 5000.0 }],
    ...
  }
}
```

---

## Key Design Decisions & Gotchas

1. **No local persistence.** SwiftData was removed. Every read and write goes to the API. There is no offline mode.

2. **Asset identity on write.** When creating a transaction, `HomeViewModel.onSave` searches existing holdings for a matching asset (by symbol for crypto/stocks/retirement, by name for cash/real estate) before creating a new asset record. This prevents duplicate asset rows for repeated transactions on the same holding.

3. **Cash & Real Estate encoding.** `quantity = dollar_amount`, `pricePerUnit = 1.0`. This is intentional — do not change without updating both client and server.

4. **Net worth snapshots are append-only.** A new snapshot is written after every transaction mutation. The chart renders all snapshots in order. No aggregation by period is currently implemented on the backend (the `period` query param is accepted but ignored).

5. **Token refresh on 401.** `APIService` retries once with a force-refreshed token. A second 401 triggers `.authenticationRequired` notification → `AuthManager.signOut()`.

6. **`@MainActor` on ViewModels and DataService.** `HomeViewModel`, `AddAssetFormViewModel`, `DataService`, and `AuthManager` are all `@MainActor`. `APIService` is not actor-isolated (it runs on cooperative thread pool via `async/await`). `AuthTokenProvider` is an `actor`.

7. **Protocol-based testability.** `ViewModels` depend on `DataServiceProtocol`; `DataService` depends on `APIServiceProtocol`. Both can be replaced with mocks in tests without any extra setup.

8. **`realEstate` vs `real_estate`.** The iOS category string for the asset bar/filter is `"realEstate"` (camelCase). `DashboardMapper` and `HomeViewModel.onSave` handle both `"real_estate"` and `"realEstate"` from the API for forward-compatibility.

---

## File Map

```
VaultTracker/
  VaultTracker/
    MainView/
      VaultTrackerApp.swift          # App entry point, TabView, root routing
    Managers/
      AuthManager.swift              # Firebase auth state, Google Sign-In
      DataService.swift              # Protocol-backed data facade
      DataServiceProtocol.swift      # Protocol for test injection
      NetworkService.swift           # Legacy (not used by APIService)
    API/
      APIConfiguration.swift         # Base URL, endpoint constants
      APIService.swift               # URLSession wrapper, 401 retry
      APIServiceProtocol.swift       # Protocol for mock injection
      AuthTokenProvider.swift        # Firebase JWT actor
      Errors/
        APIError.swift               # Typed error enum
      Models/
        APIAccountModels.swift
        APIAssetModels.swift
        APIDashboardResponse.swift
        APIErrorResponse.swift
        APINetWorthHistoryResponse.swift
        APITransactionModels.swift
      Mappers/
        AccountMapper.swift
        AssetMapper.swift
        DashboardMapper.swift
        TransactionMapper.swift
    Models/
      Account.swift                  # Domain model
      AssetModel.swift               # Domain model + AssetCategory enum
      NetWorthSnapshot.swift
      Transaction.swift
    Home/
      HomeView.swift                 # Main dashboard UI
      HomeViewModel.swift            # Dashboard state + transaction save logic
      HomeViewWrapper.swift
      NetWorthChartView.swift        # Swift Charts line/area chart
    AddAssetModal/
      AddAssetModalView.swift
      AddAssetFormViewModel.swift    # Form state + account resolution
    Login/
      LoginView.swift
    Loading/
      LoadingView.swift
    Profile/
      ProfileView.swift
    AssetCategoryView.swift
    Custom UI Components/
      CustomButtonView.swift
      CustomTextField.swift
    Utils/
      Extensions.swift               # currencyFormat, twoDecimalString
      Utilities.swift                # getTopViewController

VaultTrackerAPI/
  app/
    main.py                          # FastAPI app, router mounting, CORS
    config.py                        # Settings (app_name, debug_auth_enabled)
    database.py                      # SQLAlchemy engine, Base, get_db
    dependencies.py                  # get_current_user (Firebase JWT / debug bypass)
    models/
      user.py
      account.py
      asset.py
      transaction.py
      networth_snapshot.py
    routers/
      dashboard.py
      accounts.py
      assets.py
      transactions.py
      networth.py
      users.py
    schemas/                         # Pydantic request/response schemas
```
