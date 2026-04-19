# AddAssetModal — System Design

## Data Flow

1. `HomeView` presents `AddAssetModalView` in a `.sheet`
2. Modal calls `viewModel.save()` on submit
3. `save()` returns an `APISmartTransactionCreateRequest?` to `HomeViewModel.onSave(smartRequest:)` via the `onSave` closure
4. `HomeViewModel` posts it to `POST /transactions/smart` via `DataService.createSmartTransaction()` and reloads the dashboard

The modal does **not** call the API directly — it only validates and builds the request struct.

## API String Mappings

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

User enters a total dollar amount. VM encodes:
- `quantity = dollarAmount`
- `pricePerUnit = 1.0`
- `symbol = nil`

This lets the backend formula `current_value = quantity * price_per_unit` track a running dollar balance.

## Validation Rules (`isFormValid`)

- `accountName` must not be blank
- `name` must not be blank
- `pricePerUnit` must be a valid non-negative number
- For categories with a symbol field (crypto, stocks, retirement): `symbol` must not be blank **or** `quantity` must be a valid positive number

`isAccountTypeValidForAssetCategory` enforces that the chosen account type makes sense for the selected category.
