# Utils

Stateless helpers and extensions used across the app.

> **VTLogging phase details, Crashlytics setup, double-log rationale:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File | Contents |
|------|----------|
| `VTLogging.swift` | `VTLogging` protocol + `VTLogLive` (OSLog + Crashlytics non-fatal in non-DEBUG); `VTLog.shared` for non-injected call sites |
| `Extensions.swift` | `Double` extensions for display formatting |
| `Utilities.swift` | UIKit-level helpers (`getTopViewController` for Google Sign-In) |

## `Double` Extensions

| Extension | Purpose |
|-----------|---------|
| `twoDecimalString` | Formats to 2 decimal places (quantity display) |
| `currencyFormat()` | Locale-aware currency string (all value display) |

## Adding Helpers

- Pure functions/extensions → `Extensions.swift` or `Extensions+<Domain>.swift`
- UIKit bridge utilities → `Utilities.swift`
- Inject `VTLoggingSpy` in tests; use `VTLog.shared` for non-injected call sites
- Do not add networking, persistence, or business logic here
