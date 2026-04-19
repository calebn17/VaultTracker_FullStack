# API Layer — System Design

## Authentication Flow

Every request is signed by the injected `AuthTokenProvider` (defaults to `AuthTokenProvider.shared`). On a 401, `APIService` force-refreshes the token and retries once. If the retry also 401s, it posts `.authenticationRequired` on `NotificationCenter` and throws `APIError.unauthorized` — `AuthManager` observes this to sign the user out.

## Debug Bypass

In DEBUG builds, `AuthTokenProvider` exposes `isDebugSession` and `forceTokenRefreshFailure` as **instance** (`nonisolated(unsafe) var`) properties, not statics.

- `instance.isDebugSession = true` bypasses Firebase and returns `"vaulttracker-debug-user"`
- Production/integration tests use `AuthTokenProvider.shared.isDebugSession = true`
- Unit tests in `APIServiceTests` create a per-test instance via `makeDebugProvider()` (`AuthTokenProvider.test_make(log:)` + `isDebugSession = true`) to avoid cross-suite races
- `forceTokenRefreshFailure = true` used in `tokenRefreshFailureAfter401LogsNotAuthenticated` test

## Date Decoding

The decoder uses a custom strategy that tries three ISO 8601 formats in order:

1. With timezone + fractional seconds
2. With timezone only
3. Naive UTC

Handles both current rows (timezone-aware) and legacy rows stored before timezone support was added.

## Environment Switching

Compile-time conditional: `#if DEBUG` → `.development` (reads `API_HOST` from scheme env vars); RELEASE archives → `.production` (`https://vaulttracker-api.onrender.com`).
