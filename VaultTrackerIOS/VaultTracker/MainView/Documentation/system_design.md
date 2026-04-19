# MainView — System Design

## Auth State Machine

`VaultTrackerApp` owns a single `@StateObject var authManager: AuthManager` and switches the root view:

| State | Root View |
|-------|-----------|
| `.authenticating` | `LoadingView` (Firebase checking session) |
| `.authenticated` | `mainView` (TabView with Home, Analytics, Profile) |
| `.unauthenticated` | `LoginView` |

`authManager` is injected as `@EnvironmentObject` into the entire view hierarchy.

## Tab Structure

```
TabView
├── Home tab        (NavigationView → HomeViewWrapper → HomeView)
├── Analytics tab   (NavigationView → AnalyticsView)
└── Profile tab     (NavigationView → ProfileView)
```

## Firebase Init

`FirebaseApp.configure()` is called in `VaultTrackerApp.init()` — must run before any Firebase API is used. Do not move or defer this call.
