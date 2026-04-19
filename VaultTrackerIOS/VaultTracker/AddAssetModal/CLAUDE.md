# Add Asset Modal

Sheet for recording a new transaction (buy or sell) for any asset category.

> **Data flow, API string mappings, cash/real estate encoding, validation rules:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File | Role |
|------|------|
| `AddAssetModalView.swift` | SwiftUI form UI |
| `AddAssetFormViewModel.swift` | Form state, validation, smart request builder |

## Key Behaviors

- Modal does **not** call the API — it only validates and builds `APISmartTransactionCreateRequest`, returned via `onSave` closure to `HomeViewModel`
- Symbol field shown only for `.crypto`, `.stocks`, `.retirement`; hidden for `.cash` and `.realEstate`
- Cash/real estate: user enters total dollar amount; VM encodes as `quantity = dollarAmount`, `pricePerUnit = 1.0`, `symbol = nil`
