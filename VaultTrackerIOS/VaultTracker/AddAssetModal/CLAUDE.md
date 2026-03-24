# Add Asset Modal

Sheet that lets the user record a new transaction (buy or sell) for any asset category.

## Files

| File | Role |
|------|------|
| `AddAssetModalView.swift` | SwiftUI form UI |
| `AddAssetFormViewModel.swift` | Form state, validation, smart request builder |

## Data Flow

1. `HomeView` presents `AddAssetModalView` in a `.sheet`.
2. The modal calls `viewModel.save()` on submit.
3. `save()` returns an `APISmartTransactionCreateRequest?` to `HomeViewModel.onSave(smartRequest:)` via the `onSave` closure.
4. `HomeViewModel` posts it to `POST /transactions/smart` via `DataService.createSmartTransaction()` and reloads the dashboard.

The modal does **not** call the API directly. It only validates the form and builds the request struct.

## Smart Transaction Request

`save()` returns `APISmartTransactionCreateRequest` — the backend resolves or creates the account and asset server-side. There is no client-side `getOrCreateAccount()` lookup anymore.

Category and account type strings passed to the API:

| `AssetCategory` | API string |
|-----------------|-----------|
| `.crypto` | `"crypto"` |
| `.stocks` | `"stocks"` |
| `.cash` | `"cash"` |
| `.realEstate` | `"realEstate"` |
| `.retirement` | `"retirement"` |

| `AccountType` | API string |
|---------------|-----------|
| `.bank` | `"bank"` |
| `.brokerage` | `"brokerage"` |
| `.cryptoExchange` | `"cryptoExchange"` |
| everything else | `"other"` |

## Cash & Real Estate Encoding

For cash and real estate, the user enters a total dollar amount, not a unit count. The VM encodes this as:
- `quantity = dollarAmount`
- `pricePerUnit = 1.0`
- `symbol = nil`

This lets the backend formula `current_value = quantity * price_per_unit` track a running dollar balance.

## Validation Rules (`isFormValid`)

- `accountName` must not be blank.
- `name` must not be blank.
- `pricePerUnit` must be a valid non-negative number.
- For categories with a symbol field (crypto, stocks, retirement): `symbol` must not be blank **or** `quantity` must be a valid positive number.

`isAccountTypeValidForAssetCategory` enforces that the chosen account type makes sense for the selected asset category (e.g., crypto only in `cryptoExchange`, `cryptoWallet`, or `other`).

## Symbol Field Visibility

Shown only for `.crypto`, `.stocks`, `.retirement`. Hidden for `.cash` and `.realEstate`. When hidden, `symbol` is sent as `nil` in the API request.
