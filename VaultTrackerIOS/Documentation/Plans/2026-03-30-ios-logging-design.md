# VaultTrackerIOS Logging Design

**Date:** 2026-03-30

---

## Context

VaultTrackerIOS has no logging infrastructure. There are five bare `print()` calls scattered across error paths — no structure, no remote reporting, no visibility in production. Adding a layered logging system will make bugs traceable during development and automatically captured in production via Firebase Crashlytics (already integrated for auth, so Crashlytics is the natural production sink).

**Current state:**
- Five `print()` calls in `HomeViewModel`, `AuthManager`, `LoginView`, `ProfileView`
- No structured logging (`OSLog`, `Logger`, or custom)
- No crash/error reporting service
- `APIError` enum is well-typed but errors are only surfaced in the UI, never reported remotely

---

## Goals

- Replace bare `print()` calls with a structured logger
- Give developers readable, filterable logs in Xcode console and Console.app during development
- Capture API errors and auth failures automatically in production via Firebase Crashlytics
- Log auth lifecycle events for tracing auth bugs
- Keep all Crashlytics coupling in one file

---

## Architecture

### Logger module (`VaultTracker/Utils/VTLogger.swift`)

A single `VTLogger` struct with three static methods, backed by Apple's `OSLog` framework:

```swift
VTLogger.info(_ message: String, context: [String: Any]? = nil)
// dev: OSLog .info level; prod: OSLog only (info suppressed by default in release builds)

VTLogger.warn(_ message: String, context: [String: Any]? = nil)
// dev: OSLog .default level; prod: OSLog + Crashlytics.recordError (non-fatal)

VTLogger.error(_ message: String, error: Error? = nil, context: [String: Any]? = nil)
// dev: OSLog .error level; prod: OSLog + Crashlytics.recordError (non-fatal)
```

**OSLog subsystem:** `"com.vaulttracker"` with per-category loggers:
- `"api"` — network requests and errors
- `"auth"` — sign-in, sign-out, token events
- `"ui"` — view-layer errors

**Rules:**
- Never crashes or throws
- Never logs PII (no tokens, no email addresses, no user IDs beyond Firebase UID for tracing)
- All Crashlytics imports live only in this file
- `info` is suppressed by the OS in production builds by default — no Crashlytics noise for routine calls
- `warn` and `error` go to Crashlytics as non-fatal events in production

### Instrumentation points

| File | What is logged |
|---|---|
| `API/APIService.swift` | Every request: method, endpoint, duration (`info`); every `APIError`: case + endpoint (`error`); 401 retry (`warn`) |
| `API/AuthTokenProvider.swift` | Force-refresh after 401 (`warn`); token fetch failure (`error`) |
| `Managers/AuthManager.swift` | Sign-in success/failure, sign-out, auth state transitions, `.authenticationRequired` notification |
| `Login/LoginView.swift` | Replace bare `print()` with `VTLogger.error` |
| `Home/HomeViewModel.swift` | Replace bare `print()` with `VTLogger.error` |
| `Profile/ProfileView.swift` | Replace bare `print()` with `VTLogger.error` |

---

## Phased Plan

### Phase 1 — Logger foundation + APIService observability

**New file:** `VaultTracker/Utils/VTLogger.swift`
- Three static methods: `info`, `warn`, `error`
- Backed by `os.Logger` with `subsystem: "com.vaulttracker"`, category per call site
- Dev path: OSLog at appropriate level with structured metadata
- Prod path: OSLog + **no-op stub** for Crashlytics (wired in Phase 3)
- Add `// TODO Phase 3: wire Crashlytics here` comment in prod paths

**Modify:** `API/APIService.swift`
- Record `Date()` before URLSession call; log `VTLogger.info` with method/endpoint/duration on success
- In the error-throw path of `perform<T>()` / `performVoid()`, call `VTLogger.error` with `APIError` case and endpoint
- In the 401 retry path, call `VTLogger.warn("401 — retrying with refreshed token", context: ["endpoint": endpoint])`

### Phase 2 — Auth event logging

**Modify:** `API/AuthTokenProvider.swift`
- Before the force-refresh `getIDTokenForcingRefresh(true)` call: `VTLogger.warn("Force-refreshing token after 401")`
- In the token fetch `catch`: `VTLogger.error("Token fetch failed", error: error)`

**Modify:** `Managers/AuthManager.swift`
- Sign-in success: `VTLogger.info("User signed in", context: ["uid": user.uid])`
- Sign-in failure: `VTLogger.error("Sign-in failed", error: error)`
- Sign-out: `VTLogger.info("User signed out")`
- `.authenticationRequired` notification posted: `VTLogger.warn("Posting authenticationRequired — signing out")`
- Replace `print("Sign in with Apple not yet implemented")` with `VTLogger.warn("Sign in with Apple not yet implemented")`

**Modify:** `Login/LoginView.swift`, `Home/HomeViewModel.swift`, `Profile/ProfileView.swift`
- Replace all `print(...)` on error paths with `VTLogger.error(...)` or `VTLogger.warn(...)` as appropriate

### Phase 3 — Firebase Crashlytics integration

**Enable Crashlytics** in the Firebase project (same project already used for Auth) and add the SDK:
- Add `FirebaseCrashlytics` to the project's Swift Package Manager dependencies (alongside existing `FirebaseAuth`)
- Add the Crashlytics Run Script build phase to the Xcode target (for dSYM uploads)
- Import `FirebaseCrashlytics` in `VaultTrackerApp.swift` and enable collection

**Modify:** `VaultTracker/Utils/VTLogger.swift`
- Replace no-op prod stubs with real Crashlytics calls:
  - `warn`: `Crashlytics.crashlytics().record(error: NSError(domain: "com.vaulttracker", code: 0, userInfo: ["message": message]))`
  - `error`: `Crashlytics.crashlytics().record(error: error ?? NSError(domain: "com.vaulttracker", code: 1, userInfo: ["message": message]))`
- Set Crashlytics custom keys for context: `Crashlytics.crashlytics().setCustomKeysAndValues(context ?? [:])`

---

## Critical Files

| File | Action |
|---|---|
| `VaultTracker/Utils/VTLogger.swift` | Create |
| `API/APIService.swift` | Modify — add request/error/401 logging |
| `API/AuthTokenProvider.swift` | Modify — add force-refresh and token failure logging |
| `Managers/AuthManager.swift` | Modify — add auth lifecycle logging, replace print() |
| `Login/LoginView.swift` | Modify — replace print() with VTLogger.error |
| `Home/HomeViewModel.swift` | Modify — replace print() with VTLogger.error |
| `Profile/ProfileView.swift` | Modify — replace print() with VTLogger.error |
| `MainView/VaultTrackerApp.swift` | Modify — enable Crashlytics collection in Phase 3 |

---

## Testing

| Test | What is verified |
|---|---|
| `VTLoggerTests.swift` (create) | `info` calls OSLog at `.info` level; `warn` and `error` call Crashlytics record in prod (mock Crashlytics); logger never throws |
| `APIServiceTests.swift` (extend) | `VTLogger.error` called on non-2xx response; `VTLogger.warn` called on 401 retry; `VTLogger.info` called on success |
| `AuthManagerTests.swift` (extend) | `VTLogger.info` on sign-in success; `VTLogger.error` on sign-in failure; `VTLogger.warn` on authenticationRequired |
| `AuthTokenProviderTests.swift` (extend) | `VTLogger.warn` on force-refresh; `VTLogger.error` on token fetch failure |

All tests inject a mock logger or use `OSLogStore` to assert log output, consistent with existing protocol-based test patterns in the project.

---

## Verification

1. **Xcode tests** (`Cmd+U`) — all unit tests pass including new logger and extended API/auth tests
2. **Dev smoke test** — run on simulator, trigger an API error, confirm structured log appears in Xcode console with subsystem `com.vaulttracker` and category `api`
3. **Console.app filter** — filter by subsystem `com.vaulttracker` to confirm all log levels appear correctly on device
4. **Production build** — archive build succeeds with no Crashlytics configuration errors
5. **Crashlytics smoke test** — trigger a `VTLogger.error` call in a TestFlight build, confirm the non-fatal event appears in the Firebase console

---

## Notes

- **`OSLog` vs `print()`**: Apple's `Logger` (iOS 14+) is the correct iOS-native approach. Unlike `print()`, OSLog entries are structured, filterable in Console.app, and automatically suppressed in production release builds at the `.info` level.
- **Crashlytics vs Sentry**: Crashlytics is the natural choice here because `FirebaseAuth` is already integrated — adding `FirebaseCrashlytics` from the same Firebase SDK avoids a second dependency and keeps the Firebase project as the single observability destination.
- **No `async` in logger**: `VTLogger` methods are synchronous and non-throwing. OSLog writes are fast and non-blocking; Crashlytics writes are async internally. The logger never awaits.
