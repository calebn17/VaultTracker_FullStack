# Loading — System Design

## When It Appears

`VaultTrackerApp` shows `LoadingView` when `authManager.authenticationState == .authenticating`. Firebase's `addStateDidChangeListener` fires almost immediately on launch; this screen is visible only briefly.

## Styling

Orange gradient (`Color(red: 1.0, green: 0.5, blue: 0.0)` → `Color(red: 0.4, green: 0.2, blue: 0.0)`) matching `LoginView`, with a white `ProgressView` and the "VaultTracker" wordmark. Creates smooth visual continuity between loading and login states.
