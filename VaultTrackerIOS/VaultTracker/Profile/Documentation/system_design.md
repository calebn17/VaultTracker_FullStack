# Profile — System Design

## Dependencies

- `AuthManager` injected as `@EnvironmentObject`
- No ViewModel — view is simple enough to access `authManager` directly

## Extending This Screen

Future additions (preferences, notifications, subscriptions) should introduce a `ProfileViewModel` rather than adding logic directly to the view. `ProfileView` should remain a thin SwiftUI file.
