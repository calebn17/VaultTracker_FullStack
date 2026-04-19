# Login — System Design

## Navigation Pattern

`LoginView` does not navigate itself — `VaultTrackerApp` switches the root view based on `authManager.authenticationState`. Successful sign-in causes Firebase's state listener to set `authenticationState = .authenticated`, and `VaultTrackerApp` transitions to `mainView` automatically.

## Debug Login

Only compiled in `#if DEBUG`. Sets `AuthTokenProvider.isDebugSession = true`, causing all subsequent API calls to use `"vaulttracker-debug-user"`. Backend must have `DEBUG_AUTH_ENABLED=true`.

## Styling

Orange gradient background (`Color(red: 1.0, green: 0.5, blue: 0.0)` → `Color(red: 0.4, green: 0.2, blue: 0.0)`). Buttons are white with black text.
