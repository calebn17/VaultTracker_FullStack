# API Layer

Centralised networking layer. All backend communication flows through here; no other layer touches URLSession directly.

> **Auth flow, debug bypass details, date decoding, environment switching:** [`Documentation/system_design.md`](../Documentation/system_design.md)

## Structure

```
API/
├── APIConfiguration.swift   # Base URLs, environment switch, endpoint constants
├── APIService.swift          # Concrete URLSession implementation
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
    ├── APIAnalyticsModels.swift
    ├── APIAssetModels.swift
    ├── APIDashboardResponse.swift
    ├── APIErrorResponse.swift
    ├── APINetWorthHistoryResponse.swift
    ├── APIPriceModels.swift
    ├── APIHouseholdModels.swift   # Household + household dashboard (camelCase JSON)
    ├── APIFIREModels.swift        # FIRE profile + projection (shared with household FIRE)
    └── APITransactionModels.swift
```

## Live Endpoints

| Constant           | Method   | Path                         |
| ------------------ | -------- | ---------------------------- |
| `dashboard`        | GET      | `/api/v1/dashboard`          |
| `analytics`        | GET      | `/api/v1/analytics`          |
| `priceRefresh`     | POST     | `/api/v1/prices/refresh`     |
| `smartTransaction` | POST     | `/api/v1/transactions/smart` |
| `transactions`     | GET/POST | `/api/v1/transactions`       |
| `accounts`         | GET/POST | `/api/v1/accounts`           |
| `assets`           | GET/POST | `/api/v1/assets`             |
| `networthHistory`  | GET      | `/api/v1/networth/history`   |
| `networthHistoryHousehold` | GET | `/api/v1/networth/history/household` |
| `households`      | POST     | `/api/v1/households`         |
| `householdsMe`    | GET      | `/api/v1/households/me`     |
| `householdsInviteCodes` | POST | `/api/v1/households/invite-codes` |
| `householdsJoin`  | POST     | `/api/v1/households/join`   |
| `householdsMeMembership` | DELETE | `/api/v1/households/me/membership` |
| `householdsMeFireProfile` | GET, PUT | `/api/v1/households/me/fire-profile` |
| `dashboardHousehold` | GET   | `/api/v1/dashboard/household` |
| `fireProfile`     | GET, PUT | `/api/v1/fire/profile`       |
| `fireProjection`  | GET      | `/api/v1/fire/projection`    |
| `clearUserData`    | DELETE   | `/api/v1/users/me/data`      |

## Adding a New Endpoint

1. Add path constant to `APIConfiguration.Endpoints`
2. Declare method on `APIServiceProtocol`
3. Implement in `APIService` using `makeRequest` + `perform` (or `performVoid`)
4. Add request/response structs to `Models/`
5. Add mapper in `Mappers/` if conversion to a domain model is needed

## What Lives Here vs. Managers/

- **API/** — raw network I/O and Codable ↔ API types only
- **Managers/DataService.swift** — orchestrates API calls and converts to domain models; ViewModels call `DataService`, not `APIService` directly. FIRE profile/projection methods return `APIFIREProfileResponse` / `APIFIREProjectionResponse` (no extra domain types).
