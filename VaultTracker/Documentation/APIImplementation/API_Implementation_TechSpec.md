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
        ├── Models/
        │   ├── APIDashboardResponse.swift       ✅ Implemented
        │   ├── APIAccountModels.swift           ✅ Implemented
        │   ├── APIAssetModels.swift             ✅ Implemented
        │   ├── APITransactionModels.swift       ✅ Implemented
        │   ├── APINetWorthHistoryResponse.swift ✅ Implemented
        │   └── APIErrorResponse.swift           ✅ Implemented
        ├── Mappers/
        │   └── (to be added in Phase 2)
        └── Errors/
            └── APIError.swift          ⏳ Pending
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

**Status:** ⏳ Pending

### Approach

1. Create `AuthTokenProvider` to retrieve Firebase JWT token
2. Inject token into all API requests via `Authorization: Bearer <token>` header
3. Handle 401 responses with token refresh or logout

---

## 6. Phase 1.5: Error Handling

**Status:** ⏳ Pending

### Planned Error Types

```swift
enum APIError: Error {
    case unauthorized           // 401
    case notFound               // 404
    case validationError(String) // 422
    case serverError            // 500
    case networkError(Error)    // Connection issues
    case decodingError(Error)   // JSON parsing failed
}
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
| `API/APIServiceProtocol.swift` | ✅ | Full protocol with all 12 async/throws methods |
| `API/APIService.swift` | ✅ | URLSession-based impl; auth stub for Phase 1.4 |
| `API/Errors/APIError.swift` | ⏳ | |
