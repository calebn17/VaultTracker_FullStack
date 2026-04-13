# Auth Gap Audit — Web + iOS

## Context

VaultTracker uses Firebase Auth (Google Sign-In) across iOS and web clients. Before investing in additional auth providers, we audited the existing auth implementation for gaps in security, UX, and robustness. Apple Sign-In is deferred — Google is sufficient for now.

---

## Audit Findings

### Web — High Priority

#### 1. React Query cache not cleared on sign-out
**Files:** `VaultTrackerWeb/src/contexts/auth-context.tsx`, `VaultTrackerWeb/src/contexts/api-client-context.tsx`

The `signOutUser` function calls `signOut(getFirebaseAuth())` and pushes to `/login`, but never clears the React Query cache. If user A signs out and user B signs in, user A's cached data may briefly appear (up to 60s `staleTime`).

**Fix:** `ApiClientProvider` (in `api-client-context.tsx`) is nested inside `QueryClientProvider`, so it can call `useQueryClient()` directly. Two places to clear:
1. In the `onUnauthorized` callback (forced sign-out on 401) — call `queryClient.clear()` alongside `signOutUser()`
2. Add a `useEffect` watching `user` — when it becomes null (normal sign-out), clear the cache

This avoids needing to thread a callback through `AuthProvider`.

### Web — Medium → High Priority

#### 2. `getToken` failure doesn't redirect to login
**File:** `VaultTrackerWeb/src/lib/api-client.ts`

Two locations where `getToken` failures are swallowed without redirecting:
- **Initial token fetch** (lines 59-65): if `auth.currentUser` is null, `getToken(false)` throws "Not signed in" but `onUnauthorized` is never called
- **Retry token fetch** (lines 72-79): if `getToken(true)` throws during the 401 retry, same problem

Both paths leave the user stuck on authenticated pages seeing error states instead of being redirected to login.

**Fix:** In both catch blocks, call `this.onUnauthorized()` before rethrowing:
```ts
// Initial fetch (lines 59-65):
try {
  token = await this.getToken(false);
} catch (tokenErr) {
  this.onUnauthorized();
  throw tokenErr;
}

// Retry fetch (lines 72-79):
try {
  freshToken = await this.getToken(true);
} catch {
  this.onUnauthorized();
  throw originalError;
}
```

#### 3. Error boundaries don't handle auth errors
**File:** `VaultTrackerWeb/src/components/route-error-fallback.tsx`

If a session expires during error recovery, the "Try again" button loops between error and retry. No "Return to login" escape hatch. This complements Finding #2 — even with `onUnauthorized` fixes, error boundaries can still trap users in retry loops if the error is caught before it reaches the API client.

**Fix:** Check if the error is auth-related (status 401 or "Not signed in" message) and show a "Sign out" / "Return to login" link in the fallback UI.

### Web — Defer to Deploy

#### 4. No security headers
**File:** `VaultTrackerWeb/next.config.ts`

No CSP, HSTS, X-Frame-Options, or other security headers. Lower priority for a personal portfolio app but becomes important before production deployment.

**Fix:** Add a `headers()` function to `next.config.ts` with standard security headers. Defer to deploy time — requires knowing the production domain for CSP.

---

### iOS — High Priority

#### 5. No timeout if Firebase auth listener never fires
**File:** `VaultTrackerIOS/VaultTracker/Managers/AuthManager.swift` (line 30, 64-68)

Initial state is `.authenticating`. If `addStateDidChangeListener` never fires (e.g., `FirebaseApp.configure()` fails), the app is stuck on `LoadingView` forever.

Note: Firebase's `addStateDidChangeListener` is documented to fire immediately with cached state, so this is an edge-case safeguard for when the SDK is in a broken state — not a commonly triggered path.

**Fix:** Add a 5-second timeout after init (Firebase fires the listener immediately with cached state, so 5s is generous). Store the `Task` handle for cancellation in `deinit`:
```swift
private var authTimeoutTask: Task<Void, Never>?

// In init, after setupSubscribers():
authTimeoutTask = Task { @MainActor [weak self] in
    try? await Task.sleep(for: .seconds(5))
    guard let self, authenticationState == .authenticating else { return }
    log.warn("Auth listener timeout — falling back to unauthenticated", category: .auth)
    authenticationState = .unauthenticated
}

// In deinit:
authTimeoutTask?.cancel()
```

#### 6. No explicit data clearing on sign-out
**File:** `VaultTrackerIOS/VaultTracker/Managers/AuthManager.swift` (lines 110-123)

Sign-out sets `authenticationState = .unauthenticated` and `user = nil`, but doesn't clear ViewModel state. SwiftUI *should* recreate `@StateObject` ViewModels when the `TabView` remounts, but this relies on view lifecycle behavior rather than explicit cleanup.

**Fix:** Post a notification (e.g., `.userDidSignOut`) from `signOut()`. ViewModels or a coordinator can observe it to explicitly reset published state. Also clear `URLSession.shared.configuration.urlCache` on sign-out to prevent HTTP-level data leakage.

### iOS — Medium Priority

#### 7. Apple Sign-In button silently does nothing
**File:** `VaultTrackerIOS/VaultTracker/Login/LoginView.swift` (lines 48-71)

The button is styled identically to the working Google button. Tapping it calls `signInWithApple()` which only logs a warning and returns normally (no throw). The user sees zero feedback — no error, no alert, no loading state.

**Fix:** Remove the Apple button until Apple Sign-In is implemented. The stub `signInWithApple()` method can also be removed from `AuthManager`.

#### 8. N concurrent 401s trigger N independent token refreshes
**File:** `VaultTrackerIOS/VaultTracker/API/APIService.swift`

When multiple requests fail with 401 simultaneously, each independently force-refreshes the token. Not incorrect but wasteful.

**Fix (defer):** Add a token refresh coalescing mechanism. This is an optimization, not a bug — defer unless performance issues are observed.

#### 9. No proactive token refresh on foreground return
No scene lifecycle observers for auth. Firebase tokens have 1-hour lifetime, so a backgrounded app may need a retry on the first request after returning.

**Fix (defer):** The existing 401-retry mechanism handles this case. The UX impact (one extra roundtrip) is minimal.

---

## What's Working Well (No Issues Found)

| Area | Assessment |
|------|-----------|
| Web: Auth guard coverage | All authenticated routes under `(authenticated)/` layout group — complete |
| Web: Loading state / flash prevention | Skeleton UI during auth resolution, `useLayoutEffect` redirect — correct |
| Web: Debug auth tree-shaking | `NODE_ENV` checks ensure debug code is eliminated in production builds |
| Web: Firebase session persistence | Default `indexedDBLocalPersistence` — sessions survive page reload |
| Web: CSRF resistance | Bearer token auth (not cookies) is inherently CSRF-resistant — no additional protection needed |
| iOS: Keychain / secure storage | Relies on Firebase SDK defaults (iOS keychain) — secure |
| iOS: Network vs auth error distinction | `APIError` cleanly separates transport, auth, and HTTP errors |
| iOS: URL scheme security | Only Google OAuth callback scheme — minimal attack surface |
| iOS: `.authenticationRequired` auto sign-out | Notification-based flow from APIService → AuthManager works correctly |
| API: JWT verification | Firebase Admin SDK verifies all tokens regardless of provider — no changes needed |

---

## Recommended Implementation Order

**Do now (this PR):**
1. **Web: Clear React Query cache on sign-out** (finding #1) — high impact, small change
2. **Web: Redirect on `getToken` failure** (finding #2) — prevents stuck error states, fix both initial and retry paths
3. **Web: Auth-aware error boundary** (finding #3) — complements #2, prevents retry loops on expired sessions
4. **iOS: Auth listener timeout** (finding #5) — prevents infinite loading
5. **iOS: Remove Apple Sign-In button** (finding #7) — prevents user confusion

**Fast follow:**
6. **iOS: Explicit sign-out data clearing** (finding #6)

**Defer to deploy time:**
7. **Web: Security headers** (finding #4) — needs production domain
8. **iOS: Token refresh coalescing** (finding #8)
9. **iOS: Foreground token refresh** (finding #9)

---

## Files to Modify

| File | Change |
|------|--------|
| `VaultTrackerWeb/src/contexts/api-client-context.tsx` | Use `useQueryClient()` to clear cache on sign-out and `onUnauthorized` |
| `VaultTrackerWeb/src/lib/api-client.ts` | Call `onUnauthorized` when `getToken` throws (both initial and retry paths) |
| `VaultTrackerWeb/src/components/route-error-fallback.tsx` | Add auth-error detection and "Return to login" link |
| `VaultTrackerIOS/VaultTracker/Managers/AuthManager.swift` | Add auth listener timeout with cancellable task |
| `VaultTrackerIOS/VaultTracker/Login/LoginView.swift` | Remove Apple Sign-In button and stub |

## Verification

### Web
- `npm run build` — no type errors
- `npm test` — existing auth tests pass + new tests for cache clearing behavior
- `npm run test:e2e` — auth E2E passes (requires running API server with `DEBUG_AUTH_ENABLED=true`)
- Manual: sign in as debug user → sign out → sign in again → verify no stale data flash
- Manual: verify error boundary shows "Return to login" when session is expired

### iOS
- Build in Xcode — no compiler errors
- `Cmd+U` — unit tests pass (update AuthManagerTests: remove Apple stub test, add timeout test with `FakeFirebaseAuthBackend` that never fires listener)
- `cd VaultTrackerIOS/VaultTracker && swiftlint lint`
- Manual: verify app doesn't get stuck on loading screen; verify Apple button is gone
