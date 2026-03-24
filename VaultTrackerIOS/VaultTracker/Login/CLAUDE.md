# Login

Entry screen shown when `AuthManager.authenticationState == .unauthenticated`.

## Files

| File | Role |
|------|------|
| `LoginView.swift` | SwiftUI login UI |

## Auth Methods

| Button | Status |
|--------|--------|
| Google Sign-In | Implemented — calls `AuthManager.signInWithGoogle()` |
| Apple Sign-In | Placeholder — `signInWithApple()` is not yet implemented |
| Debug Login | DEBUG builds only — calls `AuthManager.signInDebug()`, bypasses Firebase |

## Debug Login

Only compiled in `#if DEBUG`. It sets `AuthTokenProvider.isDebugSession = true`, which causes all subsequent API calls to use the hardcoded token `"vaulttracker-debug-user"`. The backend must have `DEBUG_AUTH_ENABLED=true` in its `.env` file for this token to be accepted.

## Navigation

`LoginView` does not navigate itself — `VaultTrackerApp` switches the root view based on `authManager.authenticationState`. Successful sign-in causes Firebase's state listener to set `authenticationState = .authenticated`, and `VaultTrackerApp` transitions to `mainView` automatically.

## Styling

Orange gradient background (`Color(red: 1.0, green: 0.5, blue: 0.0)` → `Color(red: 0.4, green: 0.2, blue: 0.0)`). Buttons are white with black text for contrast.
