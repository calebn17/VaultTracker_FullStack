# Utils — System Design

## VTLogging — Implementation Details

### Phase 2 (auth + UI)

`AuthTokenProvider` logs force-refresh and token fetch failures (`.auth`). `AuthManager` logs sign-in success (uid), sign-in failure, sign-out, `authenticationRequired` handling. Views use `VTLog.shared` with `.ui` for handler errors.

### Phase 3 (Crashlytics)

In non-DEBUG builds, `VTLogLive.warn`/`error` call `Crashlytics.record` with `VTLogCrashlyticsSupport.recordableNSError`:

- Domain: `com.vaulttracker`, code 0 = warn, code 1 = error
- Custom keys per event: `vt_category`, `vt_level`, and fixed slots `vt_ctx_0`…`vt_ctx_7`
- Each slot: `sanitizedKey=String(describing: value)` or `""` when unused (prevents stale values)
- `VaultTrackerApp` enables collection in Release, disables in Debug
- Crashlytics run script uses `-gsp` pointing at `VaultTracker/GoogleService-Info.plist`

### Double Logs on API Error Paths (Intentional)

In `APIService.execute`:

1. `info` emitted after `URLSession` returns — records raw HTTP outcome and timing
2. `error` emitted if status is not 2xx or decoding fails — records the app-level `APIError`

Do not "fix" by skipping the first log on failure without an explicit design change.

### Context Shorthands

`extension VTLogging` adds overloads without `context:` (`info(_:category:)`, `warn(_:category:)`, `error(_:error:category:)`). Use the full methods when attaching structured fields.

### Testing

`VTLogCrashlyticsSupportTests` asserts helper output. Crashlytics SDK is not invoked under DEBUG. End-to-end delivery verified via Archive + TestFlight / Firebase console.
