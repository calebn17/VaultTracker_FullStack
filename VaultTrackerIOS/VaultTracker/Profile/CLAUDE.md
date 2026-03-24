# Profile

Simple settings/account screen. Second tab in the main `TabView`.

## Files

| File | Role |
|------|------|
| `ProfileView.swift` | SwiftUI view — welcome message + sign-out button |

## Current Functionality

- Displays `authManager.user?.displayName` from Firebase.
- Sign Out button calls `authManager.signOut()`, which triggers Firebase sign-out and sets `authenticationState = .unauthenticated`, causing `VaultTrackerApp` to switch back to `LoginView`.

## Dependencies

- `AuthManager` injected as `@EnvironmentObject`.
- No ViewModel — the view is simple enough that it accesses `authManager` directly.

## Extending This Screen

Future additions (user preferences, notification settings, subscription management, etc.) should introduce a `ProfileViewModel` rather than adding logic directly to the view. The `ProfileView` should remain a thin SwiftUI file.
