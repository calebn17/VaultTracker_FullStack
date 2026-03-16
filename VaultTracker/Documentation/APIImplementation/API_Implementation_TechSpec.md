# API Implementation Technical Specification

**Version:** 1.0
**Last Updated:** January 11, 2026

This document provides detailed technical specifications for the VaultTracker iOS app's API integration layer. It is updated as implementation progresses.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Phase 1.1: Configuration & Setup](#2-phase-11-configuration--setup)
3. [Phase 1.2: API Response Models](#3-phase-12-api-response-models)
4. [Phase 1.3: APIService Implementation](#4-phase-13-apiservice-implementation)
5. [Phase 1.4: Authentication Integration](#5-phase-14-authentication-integration)
6. [Phase 1.5: Error Handling](#6-phase-15-error-handling)
7. [Phase 3: DataService Refactoring](#7-phase-3-dataservice-refactoring)

---

## 1. Project Structure

All API-related code lives under `VaultTracker/VaultTracker/API/`:

```
VaultTracker/
└── VaultTracker/
    └── API/
        ├── APIConfiguration.swift      ✅ Implemented
        ├── APIService.swift            ✅ Implemented
        ├── APIServiceProtocol.swift    ✅ Implemented
        ├── AuthTokenProvider.swift     ✅ Implemented
        ├── Models/
        │   ├── APIDashboardResponse.swift       ✅ Implemented
        │   ├── APIAccountModels.swift           ✅ Implemented
        │   ├── APIAssetModels.swift             ✅ Implemented
        │   ├── APITransactionModels.swift       ✅ Implemented
        │   ├── APINetWorthHistoryResponse.swift ✅ Implemented
        │   └── APIErrorResponse.swift           ✅ Implemented
        ├── Mappers/
        │   ├── AccountMapper.swift     ✅ Implemented
        │   ├── AssetMapper.swift       ✅ Implemented
        │   ├── TransactionMapper.swift ✅ Implemented
        │   └── DashboardMapper.swift   ✅ Implemented
        └── Errors/
            └── APIError.swift          ✅ Implemented
```

---

## 2. Phase 1.1: Configuration & Setup

**Status:** ✅ Complete

### File: `APIConfiguration.swift`

**Purpose:** Centralized configuration for API environment, base URLs, and endpoint definitions.

### Implementation Details

#### APIEnvironment Enum

Defines three deployment environments with their respective base URLs:

```swift
enum APIEnvironment {
    case development   // http://localhost:8000
    case staging       // TBD
    case production    // TBD
}
```

**Usage:** Change `APIConfiguration.environment` to switch between environments. This is a compile-time setting.

#### APIConfiguration Enum

Static configuration container with:

| Property | Type | Description |
|----------|------|-------------|
| `environment` | `APIEnvironment` | Current active environment |
| `baseURL` | `String` | Base URL from current environment |
| `apiVersion` | `String` | API version prefix (`/api/v1`) |
| `baseAPIPath` | `String` | Combined base URL + version |

#### Endpoints Nested Enum

All API endpoints defined as static properties:

| Endpoint | Path | HTTP Method | Description |
|----------|------|-------------|-------------|
| `root` | `/` | GET | API info |
| `health` | `/health` | GET | Health check |
| `dashboard` | `/api/v1/dashboard` | GET | Aggregated dashboard data |
| `accounts` | `/api/v1/accounts` | GET, POST | List/create accounts |
| `account(id:)` | `/api/v1/accounts/{id}` | GET, PUT, DELETE | Single account operations |
| `assets` | `/api/v1/assets` | GET, POST | List/create assets |
| `asset(id:)` | `/api/v1/assets/{id}` | GET | Single asset details |
| `transactions` | `/api/v1/transactions` | GET, POST | List/create transactions |
| `transaction(id:)` | `/api/v1/transactions/{id}` | GET, PUT, DELETE | Single transaction operations |
| `networthHistory` | `/api/v1/networth/history` | GET | Historical snapshots |

#### URL Builder

```swift
static func url(for endpoint: String) -> String
```

Constructs full URL by combining `baseURL` with the endpoint path.

**Example:**
```swift
let url = APIConfiguration.url(for: APIConfiguration.Endpoints.dashboard)
// Returns: "http://localhost:8000/api/v1/dashboard"
```

---

## 3. Phase 1.2: API Response Models

**Status:** ✅ Complete

All models conform to `Codable` and use `CodingKeys` to map between Swift camelCase and API snake_case.

### File: `APIDashboardResponse.swift`

**Purpose:** Response model for `GET /api/v1/dashboard`

| Struct | Properties | Notes |
|--------|------------|-------|
| `APIDashboardResponse` | `totalNetWorth`, `categoryTotals`, `groupedHoldings` | Main response |
| `APICategoryTotals` | `crypto`, `stocks`, `cash`, `realEstate`, `retirement` | All `Double` |
| `APIGroupedHolding` | `id`, `name`, `symbol?`, `quantity`, `currentValue` | Uses CodingKeys for `current_value` |

### File: `APIAccountModels.swift`

**Purpose:** Request/response models for account endpoints

| Struct | Usage | Notes |
|--------|-------|-------|
| `APIAccountResponse` | GET/POST/PUT responses | Conforms to `Identifiable` |
| `APIAccountCreateRequest` | POST body | `name`, `accountType` |
| `APIAccountUpdateRequest` | PUT body | All fields optional |
| `APIAccountType` (enum) | Valid types | `cryptoExchange`, `brokerage`, `bank`, `retirement`, `other` |

### File: `APIAssetModels.swift`

**Purpose:** Request/response models for asset endpoints

| Struct | Usage | Notes |
|--------|-------|-------|
| `APIAssetResponse` | GET/POST responses | Conforms to `Identifiable` |
| `APIAssetCreateRequest` | POST body | `name`, `symbol?`, `category`, `quantity`, `currentValue` |
| `APIAssetCategory` (enum) | Valid categories | `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |

### File: `APITransactionModels.swift`

**Purpose:** Request/response models for transaction endpoints

| Struct | Usage | Notes |
|--------|-------|-------|
| `APITransactionResponse` | GET/POST/PUT responses | Conforms to `Identifiable` |
| `APITransactionCreateRequest` | POST body | `assetId`, `accountId`, `transactionType`, `quantity`, `pricePerUnit`, `date?` |
| `APITransactionUpdateRequest` | PUT body | All fields optional |
| `APITransactionType` (enum) | Valid types | `buy`, `sell` |

### File: `APINetWorthHistoryResponse.swift`

**Purpose:** Response model for `GET /api/v1/networth/history`

| Struct | Properties | Notes |
|--------|------------|-------|
| `APINetWorthHistoryResponse` | `snapshots: [APINetWorthSnapshot]` | Wrapper |
| `APINetWorthSnapshot` | `date`, `value` | Individual snapshot |
| `APINetWorthPeriod` (enum) | Query param | `daily`, `weekly`, `monthly` |

### File: `APIErrorResponse.swift`

**Purpose:** Standard error response formats

| Struct | Usage | Notes |
|--------|-------|-------|
| `APIErrorResponse` | General errors | `detail: String` |
| `APIValidationErrorResponse` | 422 errors | FastAPI validation format |
| `APIValidationErrorDetail` | Error details | `loc`, `msg`, `type` |

### CodingKeys Mappings

All snake_case API fields are mapped to camelCase Swift properties:

| API Field | Swift Property |
|-----------|----------------|
| `user_id` | `userId` |
| `account_id` | `accountId` |
| `asset_id` | `assetId` |
| `account_type` | `accountType` |
| `transaction_type` | `transactionType` |
| `price_per_unit` | `pricePerUnit` |
| `current_value` | `currentValue` |
| `created_at` | `createdAt` |
| `last_updated` | `lastUpdated` |

---

## 4. Phase 1.3: APIService Implementation

**Status:** ✅ Complete

### Design Decisions

- **Bypass existing `NetworkService`:** `NetworkService.body` is typed as `[String: String]?`, which cannot encode typed `Codable` request structs. `APIService` uses `URLSession` directly with `JSONEncoder`/`JSONDecoder`.
- **Auth stub:** A `TODO` comment marks the exact line where `Authorization: Bearer <token>` will be injected in Phase 1.4.
- **Singleton:** `APIService.shared` follows the same pattern as `NetworkService.sharedInstance`.
- **Temporary error type:** `APIServiceError` is defined inline for Phase 1.3. It will be replaced/extended by `APIError.swift` in Phase 1.5.

### File: `APIServiceProtocol.swift`

Defines every API operation as `async throws`. Grouping by resource:

| Method | Signature | HTTP |
|--------|-----------|------|
| `fetchDashboard` | `() -> APIDashboardResponse` | GET `/dashboard` |
| `fetchAccounts` | `() -> [APIAccountResponse]` | GET `/accounts` |
| `createAccount` | `(APIAccountCreateRequest) -> APIAccountResponse` | POST `/accounts` |
| `updateAccount` | `(id:, APIAccountUpdateRequest) -> APIAccountResponse` | PUT `/accounts/{id}` |
| `deleteAccount` | `(id:)` | DELETE `/accounts/{id}` |
| `fetchAssets` | `() -> [APIAssetResponse]` | GET `/assets` |
| `fetchAsset` | `(id:) -> APIAssetResponse` | GET `/assets/{id}` |
| `fetchTransactions` | `() -> [APITransactionResponse]` | GET `/transactions` |
| `createTransaction` | `(APITransactionCreateRequest) -> APITransactionResponse` | POST `/transactions` |
| `updateTransaction` | `(id:, APITransactionUpdateRequest) -> APITransactionResponse` | PUT `/transactions/{id}` |
| `deleteTransaction` | `(id:)` | DELETE `/transactions/{id}` |
| `fetchNetWorthHistory` | `(period: APINetWorthPeriod?) -> APINetWorthHistoryResponse` | GET `/networth/history` |

### File: `APIService.swift`

#### Private Helpers

| Helper | Purpose |
|--------|---------|
| `makeRequest(endpoint:method:queryItems:)` | Builds `URLRequest` for GET/DELETE (no body) |
| `makeRequest(endpoint:method:body:queryItems:)` | Builds `URLRequest` for POST/PUT with JSON-encoded `Encodable` body |
| `perform<T: Decodable>(_ request:)` | Executes request, validates status, decodes response |
| `performVoid(_ request:)` | Executes request, validates status, ignores body (used for DELETE) |
| `validate(response:data:)` | Throws `APIServiceError.httpError` for non-2xx status codes |

#### Decoder/Encoder Configuration

```swift
decoder.dateDecodingStrategy = .iso8601
encoder.dateEncodingStrategy = .iso8601
```

ISO 8601 matches the FastAPI backend's default date serialization format.

#### Temporary Error Type

```swift
enum APIServiceError: Error {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
}
```

This will be superseded by `APIError.swift` (Phase 1.5) which adds user-facing messages and specific HTTP status case mapping.

---

## 5. Phase 1.4: Authentication Integration

**Status:** ✅ Complete

### Design Decisions

- **`AuthTokenProvider` is an `actor`:** Multiple concurrent async tasks can request a token simultaneously; the actor serializes access automatically.
- **Auth in `APIService`, not `NetworkService`:** The TODO originally called for modifying `NetworkService`, but since `APIService` bypasses `NetworkService` entirely, auth injection was placed directly in `APIService.makeRequest`.
- **401 retry with force-refresh:** Firebase tokens are valid for 1 hour. A 401 usually means the token just expired. The service automatically force-refreshes and retries once before giving up.
- **Auto-logout via Notification:** `APIService` doesn't hold a reference to `AuthManager` (avoids coupling). Instead it posts `.authenticationRequired`. `AuthManager` observes this notification and calls `signOut()`.

### File: `AuthTokenProvider.swift`

```swift
actor AuthTokenProvider {
    static let shared = AuthTokenProvider()

    func getToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthTokenError.notAuthenticated
        }
        return try await user.getIDTokenForcingRefresh(forceRefresh)
    }
}
```

`getIDTokenForcingRefresh(false)` returns the cached token if valid (<1 hour old), making normal-path requests zero-overhead.

### Auth Flow in `APIService`

| Step | Action |
|------|--------|
| 1 | `makeRequest` calls `AuthTokenProvider.shared.getToken()` |
| 2 | Token set as `Authorization: Bearer <token>` header |
| 3 | Request executed via `URLSession` |
| 4 | If response is 401 → `retryWithRefreshedToken` called |
| 5 | `getToken(forceRefresh: true)` forces Firebase to fetch a new token |
| 6 | Request retried with fresh token |
| 7 | If retry also 401 → post `.authenticationRequired` notification + throw `.unauthorized` |

### `AuthManager` Changes

Added a `NotificationCenter` observer in `setupSubscribers()`:

```swift
NotificationCenter.default.addObserver(
    forName: .authenticationRequired,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        try? self?.signOut()
    }
}
```

### `Notification.Name` Extension

```swift
extension Notification.Name {
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
```

Defined in `APIService.swift` so the notification name is owned by the layer that posts it.

---

## 6. Phase 1.5: Error Handling

**Status:** ✅ Complete

### File: `API/Errors/APIError.swift`

Replaces the temporary `APIServiceError` that lived inline in `APIService.swift`.

#### Error Cases

| Case | Trigger | User-Facing Message |
|------|---------|---------------------|
| `notAuthenticated` | No Firebase user signed in | "You are not signed in…" |
| `unauthorized` | 401 after token refresh | "Your session has expired…" |
| `forbidden` | 403 | "You don't have permission…" |
| `notFound` | 404 | "The requested item could not be found." |
| `validationError([String])` | 422 with FastAPI field errors | "Invalid data: \<fields\>." |
| `serverError(Int)` | 5xx | "A server error occurred (code N)…" |
| `networkError(Error)` | URLSession transport failure | "A network error occurred…" |
| `decodingError(Error)` | JSON decode failure | "Received an unexpected response…" |
| `unknown(Int)` | Any other status code | "An unexpected error occurred (code N)." |

#### HTTP Status Mapping

`APIError.from(statusCode:data:decoder:)` is called by `APIService.validate(response:data:)`:

```swift
static func from(statusCode: Int, data: Data, decoder: JSONDecoder) -> APIError {
    switch statusCode {
    case 401: return .unauthorized
    case 403: return .forbidden
    case 404: return .notFound
    case 422: return .validationError(parseValidationMessages(from: data, decoder: decoder))
    case 500...599: return .serverError(statusCode)
    default: return .unknown(statusCode)
    }
}
```

For 422 responses, `parseValidationMessages` decodes `APIValidationErrorResponse` (defined in Phase 1.2) and flattens each field error into `"<field>: <message>"` strings.

#### `LocalizedError` Conformance

`APIError` conforms to `LocalizedError` via `var errorDescription: String?`. SwiftUI's `.alert(error:)` and any catch block using `error.localizedDescription` will produce human-readable text automatically — no extra mapping needed in ViewModels.

#### `APIService` Updates

- `APIServiceError` enum removed — `APIError` is the single error type
- `execute(_:)` helper added: wraps `URLSession.data(for:)` and catches transport errors as `APIError.networkError`
- `validate(response:data:)` now calls `APIError.from(statusCode:data:decoder:)` instead of throwing a raw code
- `decodeResponse(_:from:)` helper added: wraps `JSONDecoder.decode` and rethrows as `APIError.decodingError`

---

## 7. Phase 2.1: Domain Model Review

**Status:** ✅ Complete (review only — no model files modified)

### Findings

| Model | Compatibility | Notes |
|-------|--------------|-------|
| `Account` | ✅ Compatible | `id: UUID` vs API `id: String` — parse via `UUID(uuidString:)` in mapper |
| `Asset` | ✅ Compatible | `symbol: String` (non-optional) vs API `symbol: String?` — fall back to name; `price` field derived as `currentValue/quantity` |
| `Transaction` | ⚠️ Requires context | Embeds `name/symbol/category` inline; API only has `assetId` — mapper requires asset lookup dict |
| `NetWorthSnapshot` | ✅ Compatible | Direct 1:1 with `APINetWorthSnapshot` |

### AccountType Mapping Gap

| App Case | API Equivalent |
|----------|---------------|
| `bank` | `bank` |
| `brokerage` | `brokerage` |
| `cryptoExchange` | `crypto_exchange` |
| `physicalWallet` | ❌ No API equivalent |
| `cryptoWallet` | ❌ No API equivalent |
| `realEstate` | ❌ No API equivalent |
| `other` | `other` |
| ❌ Not in app | `retirement` → maps to `.other` |

### GroupedAssetHolding Shape Mismatch

- **App:** `[accountName: [assetIdentifier: AssetHolding]]`
- **API:** `[category: [APIGroupedHolding]]`

These are structurally different. `DashboardMapper` bridges this by using holding name as the outer key and symbol as the inner key. **Phase 4.2** will resolve this by restructuring `HomeViewState` to match the API shape.

---

## 8. Phase 2.2: Mappers

**Status:** ✅ Complete

All mappers live under `API/Mappers/` as caseless enums with static methods.

### `AccountMapper.swift`

`toDomain(_ response: APIAccountResponse) -> Account`

- Parses `id: String` → `UUID` via `UUID(uuidString:) ?? UUID()`
- Maps API account type strings (including `crypto_exchange` snake_case variant)
- `retirement` API type maps to `.other` (closest local equivalent)

### `AssetMapper.swift`

`toDomain(_ response: APIAssetResponse) -> Asset`

- `symbol: String?` → `String` falls back to `asset.name`
- Derives `price` (purchase price) as `currentValue / quantity` — temporary bridge until domain model is simplified in Phase 4
- `mapCategory(_:)` is `internal` (not private) so `DashboardMapper` can reuse it

### `TransactionMapper.swift`

`toDomain(_ response:, assetsByID:, accountsByID:) -> Transaction?`

- Returns `nil` if asset or account cannot be resolved from the provided dictionaries — caller uses `compactMap`
- Callers must build `[serverID: Asset]` and `[serverID: Account]` lookup dicts before calling

### `DashboardMapper.swift`

`toViewState(_ response: APIDashboardResponse) -> HomeViewState`

- Maps all 5 category totals and `totalNetWorth` directly
- Bridges `groupedHoldings` using holding name as outer key and symbol as inner key
- Documents the shape mismatch with a comment pointing to Phase 4

---

---

## 7. Phase 3: DataService Refactoring

**Status:** ✅ Complete (3.1 – 3.6)

### Overview

Replaces the SwiftData-backed `DataService` with an API-driven implementation. All reads and writes now go through `APIService`, with Phase 2 mapper functions converting API response types into domain models.

### New Files

#### `Managers/DataServiceProtocol.swift`

Defines the public data-access interface consumed by `HomeViewModel` and `AddAssetFormViewModel`. All methods are `async throws`.

| Method | Returns | Notes |
|--------|---------|-------|
| `fetchDashboard()` | `APIDashboardResponse` | Passthrough to APIService |
| `fetchAllTransactions()` | `[Transaction]` | Parallel fetch of txs + assets + accounts; mapped via TransactionMapper |
| `createTransaction(_:)` | `Transaction` | Posts request; resolves asset + account for mapping |
| `deleteTransaction(id:)` | `Void` | DELETE by server UUID string |
| `fetchAllAssets()` | `[Asset]` | Mapped via AssetMapper |
| `createAsset(_:)` | `Asset` | POST; mapped via AssetMapper |
| `fetchAllAccounts()` | `[Account]` | Mapped via AccountMapper |
| `createAccount(_:)` | `Account` | POST; mapped via AccountMapper |
| `updateAccount(id:_:)` | `Account` | PUT; mapped via AccountMapper |
| `deleteAccount(id:)` | `Void` | DELETE by server UUID string |
| `fetchNetWorthHistory(period:)` | `[NetWorthSnapshot]` | Maps APINetWorthSnapshot → domain NetWorthSnapshot |

### Updated Files

#### `Managers/DataService.swift` — complete rewrite

- Removed: `ModelContext`, `AssetManager`, `assetPrices`, `isAssetPriceRefreshed`
- Added: `private let api: APIServiceProtocol` injected via `init(api:)` (defaults to `APIService.shared`)
- Marked `@MainActor` because `Asset` and `NetWorthSnapshot` are `@MainActor @Model`
- `fetchAllTransactions()` uses `async let` to fetch transactions, assets, and accounts in parallel before mapping
- `createTransaction(_:)` fetches the created asset and all accounts after POST to resolve the domain model
- `fetchNetWorthHistory(period:)` maps `APINetWorthSnapshot` directly to `NetWorthSnapshot(date:value:)` without inserting into SwiftData

**Removed methods (Phase 3.2 – 3.6):**
- `addTransaction(_:)`, `deleteAllTransactions()`, `fetchTransactions(after:)`
- `addAsset(_:)`, `deleteAsset(_:)`, `deleteAllAssets()`, `fetchLatestPrice(_:)`, `refreshAllPrices()`
- `addAccount(_:)`, `fetchAccount(named:)`
- `addSnapshot(_:)`, `deleteAllSnapshots()`, `fetchAllNetworthSnapshots()`
- `saveContext()`, `insertModel(_:)`, `deleteModel(_:)`

#### `API/APIServiceProtocol.swift` + `API/APIService.swift`

Added `createAsset(_ request: APIAssetCreateRequest) async throws -> APIAssetResponse` — needed so `DataService` and `HomeViewModel.onSave` can create assets on the backend before posting a transaction for a new holding.

#### `AddAssetModal/AddAssetFormViewModel.swift`

- `dataService` type changed to `DataServiceProtocol`
- Init no longer passes `ModelContext` to `DataService`
- `getOrCreateAccount()` now calls `dataService.fetchAllAccounts()` to look up by name, then `dataService.createAccount(_:)` if not found — ensuring the `Account` returned has a server-side UUID that `HomeViewModel.onSave` can use as `accountId`

#### `Home/HomeViewModel.swift`

- `dataService` type changed to `DataServiceProtocol`
- `DataService()` no longer receives `ModelContext`
- Removed: `refreshPrices()` method and its call in `loadData`
- `clearData()` stubbed with print — no API equivalent; removed in Phase 6.1
- `onSave(transaction:)` rewritten: looks up asset UUID in `self.assets` (server UUIDs), creates asset via API if new, then POSTs `APITransactionCreateRequest`, then calls `loadAssets()` to refresh quantities/values
- `rebuildHistoricalSnapshots()` replaced with `dataService.fetchNetWorthHistory(period: nil)`
- Removed: `updatePricesForGroupedAssetHoldings()` and its call in `processGroupTransactions`

### Architecture After Phase 3

```
HomeViewModel / AddAssetFormViewModel
        ↓  DataServiceProtocol
    DataService  (@MainActor)
        ↓  APIServiceProtocol
    APIService  (URLSession + auth)
        ↓  Phase 2 Mappers
    Domain models (Asset, Account, Transaction, NetWorthSnapshot)
```

---

## Appendix: File Checklist

| File | Status | Notes |
|------|--------|-------|
| `API/APIConfiguration.swift` | ✅ | Environment, URLs, endpoints |
| `API/Models/APIDashboardResponse.swift` | ✅ | Dashboard + category totals + grouped holdings |
| `API/Models/APIAccountModels.swift` | ✅ | Response, create, update + account type enum |
| `API/Models/APIAssetModels.swift` | ✅ | Response, create + category enum |
| `API/Models/APITransactionModels.swift` | ✅ | Response, create, update + transaction type enum |
| `API/Models/APINetWorthHistoryResponse.swift` | ✅ | History response + snapshot + period enum |
| `API/Models/APIErrorResponse.swift` | ✅ | Standard + validation error formats |
| `API/APIServiceProtocol.swift` | ✅ | 13 async/throws methods (added createAsset in Phase 3) |
| `API/APIService.swift` | ✅ | URLSession-based impl; auth injection + 401 retry |
| `API/AuthTokenProvider.swift` | ✅ | Actor wrapping Firebase getIDTokenForcingRefresh |
| `API/Mappers/AccountMapper.swift` | ✅ | APIAccountResponse → Account |
| `API/Mappers/AssetMapper.swift` | ✅ | APIAssetResponse → Asset |
| `API/Mappers/TransactionMapper.swift` | ✅ | APITransactionResponse → Transaction (needs asset+account dicts) |
| `API/Mappers/DashboardMapper.swift` | ✅ | APIDashboardResponse → HomeViewState |
| `API/Errors/APIError.swift` | ✅ | LocalizedError enum + HTTP status mapping |
| `Managers/AuthManager.swift` | ✅ (modified) | Observes .authenticationRequired for auto-logout |
| `Managers/DataServiceProtocol.swift` | ✅ | New in Phase 3 — defines data-access interface |
| `Managers/DataService.swift` | ✅ (rewritten) | API-backed; no SwiftData; @MainActor |
| `AddAssetModal/AddAssetFormViewModel.swift` | ✅ (modified) | Uses DataServiceProtocol; API account lookup |
| `Home/HomeViewModel.swift` | ✅ (modified) | Uses DataServiceProtocol; API-driven onSave + chart |
| `API/Errors/APIError.swift` | ✅ | LocalizedError + HTTP status mapping + 422 parsing |
