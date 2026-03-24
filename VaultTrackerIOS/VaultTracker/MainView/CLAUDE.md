# MainView

App entry point and root navigation container.

## Files

| File | Role |
|------|------|
| `VaultTrackerApp.swift` | `@main` struct, Firebase init, root scene, auth state switch |

## Auth State Machine

`VaultTrackerApp` owns a single `@StateObject var authManager: AuthManager` and switches the root view based on `authManager.authenticationState`:

| State | Root View |
|-------|-----------|
| `.authenticating` | `LoadingView` (shown briefly on launch while Firebase checks session) |
| `.authenticated` | `mainView` (TabView with Home, Analytics, and Profile) |
| `.unauthenticated` | `LoginView` |

`authManager` is injected as an `@EnvironmentObject` into the entire view hierarchy.

## Tab Structure

```
TabView
├── Home tab        (NavigationView → HomeViewWrapper → HomeView)
├── Analytics tab   (NavigationView → AnalyticsView)
└── Profile tab     (NavigationView → ProfileView)
```

| Tab | SF Symbol | Label |
|-----|-----------|-------|
| Home | `house` | Home |
| Analytics | `chart.pie.fill` | Analytics |
| Profile | `person.crop.circle` | Profile |

## Adding a New Tab

1. Create the screen in its own folder (e.g., `NewFeature/NewFeatureView.swift`).
2. Add a new `NavigationView` wrapping it inside the `TabView` in `VaultTrackerApp.mainView`.
3. Provide a `.tabItem` with an SF Symbol and a label string.

## Firebase Init

`FirebaseApp.configure()` is called in `VaultTrackerApp.init()` — it must run before any Firebase API is used. Do not move or defer this call.
