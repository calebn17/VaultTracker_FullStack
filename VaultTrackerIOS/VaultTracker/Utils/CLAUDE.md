# Utils

Stateless helpers and extensions used across the app.

## Files

| File | Contents |
|------|----------|
| `VTLogging.swift` | `VTLogging` protocol + `VTLogLive` (OSLog + Crashlytics non-fatal in non-DEBUG); `VTLogCrashlyticsSupport` (pure helpers for custom keys / `NSError` payload); `VTLog.shared` for views and non-injected call sites; inject `VTLoggingSpy` in tests |
| `Extensions.swift` | `Double` extensions for display formatting |
| `Utilities.swift` | `Utilities` singleton for UIKit-level helpers |

## `VTLogging`

- **`VTLog.shared`** — Default `any VTLogging` (`VTLogLive`) for `ProfileView`, `HomeViewModel`, `AuthTokenProvider`, and anywhere else that is not constructed with an injected logger. Sign-in errors are logged only in `AuthManager` (not in `LoginView`). `APIService` and `AuthManager` use injectable log instances (`VTLogLive()` / `VTLog.shared` defaults).
- **Phase 2 (auth + UI)** — `AuthTokenProvider` logs force-refresh and token fetch failures (`.auth`). `AuthManager` logs sign-in success (uid in context), sign-in failure, sign-out, `authenticationRequired` handling, and the Sign in with Apple placeholder. Views use `VTLog.shared` with `.ui` for handler errors.
- **Phase 3 (Crashlytics)** — In non-DEBUG builds, `VTLogLive.warn` / `error` call `Crashlytics.record` with `VTLogCrashlyticsSupport.recordableNSError` (domain `com.vaulttracker`, code 0 = warn, 1 = error). Custom keys are always the same set per event: `vt_category`, `vt_level`, and fixed slots `vt_ctx_0`…`vt_ctx_7` (see `crashlyticsContextSlotCount`). Each slot value is `sanitizedKey=String(describing: value)` for the next context entry in ascending key order, or `""` when unused so Crashlytics does not keep stale values from a previous non-fatal. `VaultTrackerApp` enables collection in Release, disables in Debug. The Crashlytics run script uses `-gsp` pointing at `VaultTracker/GoogleService-Info.plist`.
- **Unit tests** — `VTLogCrashlyticsSupportTests` asserts the helper output (Crashlytics SDK is not invoked under DEBUG). End-to-end non-fatal delivery is verified via Archive + TestFlight / Firebase console.
- **Context shorthands** — `extension VTLogging` adds overloads without `context:` (equivalent to `context: nil`): `info(_:category:)`, `warn(_:category:)`, and `error(_:error:category:)` (same `error:` label as the full API; implementation uses `error err:` internally to avoid shadowing). Use the full methods when attaching structured fields.
- **Double logs on some API error paths (intentional)** — In `APIService`, `execute` always emits an `info` (“HTTP … completed” with `endpoint`, `status`, `durationMs`) after `URLSession` returns. If the status is not 2xx or decoding fails, a second line is emitted: an `error` from `validate` or `decodeResponse` with the mapped `APIError` and fields like `case`. That pair is deliberate: the first line records the raw HTTP outcome and timing; the second records the app-level error for filtering and Crashlytics. Do not “fix” by skipping the first log on failure without an explicit design change.

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
