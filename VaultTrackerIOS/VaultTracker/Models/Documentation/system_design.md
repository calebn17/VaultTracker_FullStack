# Models — System Design

## Type Details

### `Asset` / `AssetCategory` (`AssetModel.swift`)

`AssetCategory` enum with raw string display values: `"Crypto"`, `"Stocks/ETFs"`, `"Real Estate"`, `"Cash"`, `"Retirement"`.

> **Backend mismatch:** The backend uses camelCase keys (`"crypto"`, `"stocks"`, `"realEstate"`) in dashboard responses. `DashboardMapper` handles conversion — do not use `AssetCategory.rawValue` for API serialisation.

### `Transaction` / `TransactionType` (`Transaction.swift`)

Embeds a full `Account` value inline (denormalised for easy display). `symbol` mirrors `name` for categories with no ticker.

`TransactionType`: raw value is `"Buy"` / `"Sell"`. When serialising to the API: `.rawValue.lowercased()`.

### `Account` / `AccountType` (`Account.swift`)

Two serialisation contexts:
- **Sent to API** (via `AddAssetFormViewModel.smartAPIAccountType()`): camelCase strings — `"bank"`, `"brokerage"`, `"cryptoExchange"`. Local-only types fall back to `"other"`.
- **Received from API** (`AccountMapper.mapAccountType(_:)`): accepts both `"crypto_exchange"` and `"cryptoExchange"` (legacy rows). Server `"retirement"` maps to `.other`.

### `NetWorthSnapshot` (`NetWorthSnapshot.swift`)

`(date: Date, value: Double)` pair. Used exclusively by `NetWorthChartView`. Created from `APINetWorthHistoryResponse` in `DataService.fetchNetWorthHistory()`.
