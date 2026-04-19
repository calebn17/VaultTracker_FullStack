# MainView

App entry point and root navigation container.

> **Auth state machine, tab structure, Firebase init:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File | Role |
|------|------|
| `VaultTrackerApp.swift` | `@main` struct, Firebase init, root scene, auth state switch |

## Adding a New Tab

1. Create the screen in its own folder (e.g., `NewFeature/NewFeatureView.swift`)
2. Add a new `NavigationView` wrapping it inside the `TabView` in `VaultTrackerApp.mainView`
3. Provide `.tabItem` with an SF Symbol and label string
