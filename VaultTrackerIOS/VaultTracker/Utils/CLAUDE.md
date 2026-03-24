# Utils

Stateless helpers and extensions used across the app.

## Files

| File | Contents |
|------|----------|
| `Extensions.swift` | `Double` extensions for display formatting |
| `Utilities.swift` | `Utilities` singleton for UIKit-level helpers |

## `Double` Extensions

| Extension | Purpose |
|-----------|---------|
| `twoDecimalString` | Formats to 2 decimal places — used for quantity display (`"1.50 coins"`) |
| `currencyFormat()` | Formats to locale-aware currency string — used for all value display |

## `Utilities`

Provides `getTopViewController()`, used by `AuthManager.signInWithGoogle()` to present the Google Sign-In flow from the correct view controller. This is a UIKit bridge required by the Google Sign-In SDK.

## Adding Helpers

- Pure functions and extensions belong in `Extensions.swift` or a new `Extensions+<Domain>.swift` file.
- UIKit bridge utilities belong in `Utilities.swift`.
- Do not add networking, persistence, or business logic here.
