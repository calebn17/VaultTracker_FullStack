# Models

Domain value types. These are the app's internal representation of data — they are distinct from the API response types in `API/Models/`. Mappers in `API/Mappers/` convert between the two.

## Types

### `Asset` (AssetModel.swift)
Represents a single trackable asset (e.g., Bitcoin, AAPL, a savings account). `symbol` is used for ticker-based assets; for cash and real estate, it duplicates `name`.

### `AssetCategory` (AssetModel.swift)
Enum with raw string display values: `"Crypto"`, `"Stocks/ETFs"`, `"Real Estate"`, `"Cash"`, `"Retirement"`. Used as a filter key in `HomeView` and as a grouping key in `DashboardMapper`.

> **Backend mismatch:** The backend uses camelCase category keys (`"crypto"`, `"stocks"`, `"realEstate"`) in dashboard responses, not the display strings. `DashboardMapper` handles the conversion; do not rely on `AssetCategory.rawValue` for API serialisation.

### `Transaction` (Transaction.swift)
A buy or sell event for an asset within an account. Embeds a full `Account` value inline rather than just an ID — the domain model is denormalised for easy display.

`symbol` mirrors `name` for categories with no ticker (cash, real estate).

### `TransactionType` (Transaction.swift)
`buy` / `sell`. Raw value is `"Buy"` / `"Sell"`. When serialised to the API, use `.rawValue.lowercased()`.

### `Account` (Account.swift)
Represents a financial account (bank, brokerage, exchange, wallet, etc.). The `AccountType` enum maps to snake_case strings for API requests (e.g., `cryptoExchange` → `"crypto_exchange"`).

### `NetWorthSnapshot` (NetWorthSnapshot.swift)
`(date: Date, value: Double)` pair. Used exclusively by `NetWorthChartView`. Created from `APINetWorthHistoryResponse` in `DataService.fetchNetWorthHistory()`.

## Rules

- Domain models are `Sendable` structs — they are safe to pass across actor boundaries.
- Domain models have no network-related dependencies (`Codable` conformance is only for `AssetCategory` and `TransactionType` where needed for local use).
- Do not add API URL paths, encoding logic, or `URLRequest` construction here.
