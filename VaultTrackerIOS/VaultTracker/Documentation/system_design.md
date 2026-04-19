# VaultTracker iOS — System Design

## Architecture

```
View  ──>  ViewModel  ──>  DataServiceProtocol
                                  │
                            DataService (concrete)
                                  │
                           APIServiceProtocol
                                  │
                            APIService (URLSession)
                                  │
                         VaultTracker REST API
```

- Views depend only on their ViewModel.
- ViewModels depend only on `DataServiceProtocol` — never on `APIService` directly.
- This allows unit testing via `MockDataService` without network calls.

## Auth Flow

Firebase manages session state. `AuthManager` publishes `authenticationState` to `VaultTrackerApp`, which switches the root view. If the Firebase auth state listener never runs, `AuthManager` falls back to unauthenticated after 5 seconds. `AuthTokenProvider` (an actor) vends Firebase JWTs to `APIService` for every request, with an automatic retry on 401.

## Environment / Backend

| Build   | Environment | Backend                                       |
| ------- | ----------- | --------------------------------------------- |
| DEBUG   | development | `API_HOST` env var (default `localhost:8000`) |
| RELEASE | production  | `https://vaulttracker-api.onrender.com`       |

Switch is compile-time `#if DEBUG` — no source change needed before archiving.

**Real device:** Set `API_HOST = 192.168.x.x:8000` in Xcode scheme env vars; both devices must be on same Wi-Fi.

## Tab Structure

| Tab       | View            | SF Symbol            |
| --------- | --------------- | -------------------- |
| Home      | `HomeView`      | `house`              |
| Analytics | `AnalyticsView` | `chart.pie.fill`     |
| Profile   | `ProfileView`   | `person.crop.circle` |

## Key Endpoints

| Operation               | Method + Path                                                |
| ----------------------- | ------------------------------------------------------------ |
| Dashboard               | `GET /api/v1/dashboard`                                      |
| Analytics               | `GET /api/v1/analytics`                                      |
| Smart transaction       | `POST /api/v1/transactions/smart`                            |
| Price refresh           | `POST /api/v1/prices/refresh`                                |
| Transactions (enriched) | `GET /api/v1/transactions`                                   |
| Net worth history       | `GET /api/v1/networth/history?period=daily\|weekly\|monthly` |

## Firebase `GoogleService-Info.plist`

Not tracked in git. Copy `GoogleService-Info.plist.example` → `GoogleService-Info.plist` and fill in values from Firebase console (Project settings → Your apps → iOS). CI copies the example to that path before `xcodebuild test`.

If this file was ever committed: **restrict keys** in Google Cloud Console and follow your team's secret-rotation policy.

## Tests

### Unit / Integration Tests (`VaultTrackerTests/`)

- **Unit tests** use Swift Testing (`@Test`, `#expect`). Covers: `HomeViewModelTests`, `AnalyticsViewModelTests`, `AddAssetFormViewModelTests`, `AuthManagerTests`, `APIServiceTests`, `AuthTokenProviderTests`.
- `APIServiceTests` uses `APIService.test_make(session:log:tokenProvider:)` with a stub `URLProtocol` session and per-test `AuthTokenProvider` via `makeDebugProvider()` — avoids cross-suite races with `AuthTokenProvider.shared`.
- `AuthManagerTests` injects `FakeFirebaseAuthBackend` + isolated `NotificationCenter` with short `authListenerTimeoutNanoseconds` for timeout tests.
- **Integration tests** (`APIIntegrationTests`, `HomeViewModelIntegrationTests`, `AddAssetFormViewModelIntegrationTests`) hit a real local API with `DEBUG_AUTH_ENABLED=true`.
- `MockDataService.swift` is the test double for `DataServiceProtocol`.

### UI Tests (`VaultTrackerUITests/`)

Page object pattern — each screen has a `struct` in `PageObjects/`:

| Page Object     | Screen                |
| --------------- | --------------------- |
| `LoginPage`     | Login                 |
| `HomePage`      | Home tab              |
| `AddAssetPage`  | Add transaction sheet |
| `AnalyticsPage` | Analytics tab         |
| `ProfilePage`   | Profile tab           |

- BDD naming: `test_given<state>_when<action>_then<outcome>`
- Elements resolved via `accessibilityIdentifier` — do not change identifiers without updating page objects
- Launch argument `-UI-Testing` enables debug auth mode
- UI tests that create data require local API with `DEBUG_AUTH_ENABLED=true`

## Refactor Plan Status

| Phase | Description                       | Status  |
| ----- | --------------------------------- | ------- |
| 1     | Point to production               | ✅ Done |
| 2     | Smart transaction endpoint        | ✅ Done |
| 3     | Enriched transaction responses    | ✅ Done |
| 4     | Analytics tab                     | ✅ Done |
| 5     | Price refresh                     | ✅ Done |
| 6     | Period-aggregated net worth chart | ✅ Done |
| 7     | Cleanup                           | ✅ Done |
