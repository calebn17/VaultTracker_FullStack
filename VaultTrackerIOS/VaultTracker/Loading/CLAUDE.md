# Loading

Splash/loading screen shown while Firebase resolves the initial auth state.

## Files

| File | Role |
|------|------|
| `LoadingView.swift` | SwiftUI full-screen loading indicator |

## When It Appears

`VaultTrackerApp` shows `LoadingView` when `authManager.authenticationState == .authenticating`. Firebase's `addStateDidChangeListener` fires almost immediately on launch; this screen is visible only for a brief moment.

## Styling

Same orange gradient as `LoginView` (`Color(red: 1.0, green: 0.5, blue: 0.0)` → `Color(red: 0.4, green: 0.2, blue: 0.0)`) with a white `ProgressView` and the "VaultTracker" wordmark. This creates a smooth visual continuity between the loading and login states.

## Notes

This view has no ViewModel and no state — it is purely presentational. Do not add logic here.
