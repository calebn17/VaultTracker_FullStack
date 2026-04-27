# Models

Domain value types — the app's internal data representation. Distinct from API response types in `API/Models/`; mappers in `API/Mappers/` convert between the two.

> **Type details, serialization contexts, backend mismatches:** [`Documentation/system_design.md`](../Documentation/system_design.md)

## Types

| Type                              | File                     | Notes                                                 |
| --------------------------------- | ------------------------ | ----------------------------------------------------- |
| `Asset` / `AssetCategory`         | `AssetModel.swift`       | Category raw values are display strings, not API keys |
| `Transaction` / `TransactionType` | `Transaction.swift`      | Denormalised — embeds full `Account` inline           |
| `Account` / `AccountType`         | `Account.swift`          | Two serialisation contexts (send vs receive)          |
| `NetWorthSnapshot`                | `NetWorthSnapshot.swift` | `(date, value)` pair for chart only                   |

## Rules

- Domain models are `Sendable` structs — safe across actor boundaries
- No network dependencies; no `URLRequest` construction here
- `Codable` only where needed for local use (not API serialisation)
