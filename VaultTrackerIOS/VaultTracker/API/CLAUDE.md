# API Layer

Centralised networking layer. All backend communication flows through here; no other layer touches URLSession directly.

## Structure

```
API/
├── APIConfiguration.swift   # Base URLs, environment switch, endpoint constants
├── APIService.swift          # Concrete URLSession implementation of APIServiceProtocol
├── APIServiceProtocol.swift  # Interface — program against this, not the concrete class
├── AuthTokenProvider.swift   # Actor that vends Firebase JWT tokens
├── Errors/
│   └── APIError.swift        # Typed error enum; maps HTTP status codes to cases
├── Mappers/
│   ├── AccountMapper.swift
│   ├── AssetMapper.swift
│   ├── DashboardMapper.swift
│   └── TransactionMapper.swift
└── Models/
    ├── APIAccountModels.swift
    ├── APIAnalyticsModels.swift    # APIAnalyticsResponse, APIAllocationEntry, APIPerformanceBlock
    ├── APIAssetModels.swift
    ├── APIDashboardResponse.swift
    ├── APIErrorResponse.swift
    ├── APINetWorthHistoryResponse.swift
    ├── APIPriceModels.swift        # APIPriceRefreshResult, APIPriceUpdate, APIPriceError
    └── APITransactionModels.swift  # Includes APISmartTransactionCreateRequest + APIEnrichedTransactionResponse
```

## Key Decisions

**Environment switching** — Compile-time conditional: `#if DEBUG` builds use `.development` (reads `API_HOST` from scheme env vars); `RELEASE` archives automatically target `.production` (`https://vaulttracker-api.onrender.com`). No manual change needed before archiving.

**Authentication** — Every request is signed by `AuthTokenProvider.shared.getToken()`. On a 401 response, `APIService` force-refreshes the token and retries once. If the retry also 401s, it posts `.authenticationRequired` on `NotificationCenter` and throws `APIError.unauthorized` — `AuthManager` observes this to sign the user out.

**Date decoding** — The decoder uses a custom strategy that tries three ISO 8601 formats in order: with timezone + fractional seconds, with timezone only, then naive UTC. This handles both current rows (timezone-aware) and legacy rows stored before timezone support was added.

**Debug bypass** — In DEBUG builds, `AuthTokenProvider.isDebugSession = true` returns a hardcoded token (`"vaulttracker-debug-user"`). The backend must have `DEBUG_AUTH_ENABLED=true` in its `.env` for this to work.

## Live Endpoints

| Constant | Method | Path |
|----------|--------|------|
| `dashboard` | GET | `/api/v1/dashboard` |
| `analytics` | GET | `/api/v1/analytics` |
| `priceRefresh` | POST | `/api/v1/prices/refresh` |
| `smartTransaction` | POST | `/api/v1/transactions/smart` |
| `transactions` | GET/POST | `/api/v1/transactions` |
| `accounts` | GET/POST | `/api/v1/accounts` |
| `assets` | GET/POST | `/api/v1/assets` |
| `networthHistory` | GET | `/api/v1/networth/history` |
| `clearUserData` | DELETE | `/api/v1/users/me/data` |

## Adding a New Endpoint

1. Add the path constant to `APIConfiguration.Endpoints`.
2. Declare the method on `APIServiceProtocol`.
3. Implement it in `APIService` using `makeRequest` + `perform` (or `performVoid` for no-body responses).
4. Add any new request/response structs to the appropriate file under `Models/`.
5. Add a mapper function in `Mappers/` if conversion to a domain model is needed.

## What Lives Here vs. Managers/

- **API/** — raw network I/O and Codable ↔ API types only.
- **Managers/DataService.swift** — orchestrates API calls and converts API types to domain models. ViewModels call `DataService`, not `APIService` directly.
