# VaultTracker iOS — System Design

## Directory map

```
VaultTracker/
├── DesignSystem/          # Digital Ledger tokens: VTColors, VTFonts (VTTypography.swift), VTComponents
├── MainView/              # App entry point, root TabView (Home, Analytics, FIRE, Profile), auth state switch
├── Login/                 # Google sign-in screen
├── Loading/               # Splash during Firebase auth check
├── Home/                  # Dashboard: net worth, category breakdown, history chart, price refresh
├── AddAssetModal/         # Sheet for buy/sell via smart endpoint
├── Analytics/             # Allocation and gain/loss
├── Fire/                    # FIRE — personal projection vs shared household inputs (no household projection in v1)
├── Profile/                 # User info, household settings, sign-out
├── API/                     # URLSession, protocols, models, mappers
├── Managers/                # DataService, AuthManager, NetworkService (legacy), Offline/ SwiftData + queue
├── Models/                  # Domain value types
├── Custom UI Components/   # Reusable SwiftUI primitives
├── Utils/                   # VTLogging, extensions, UIKit bridges
└── Assets.xcassets
```

Subfolders may define their own `CLAUDE.md` for file-specific rules.

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

- **Home (optional path):** `VaultTrackerApp` creates `LocalDataStack` (SwiftData + sync) and injects `DataRepository` into `HomeViewModel` for cached dashboard, net worth history, and offline smart transaction queue. See [Offline & local data (Home)](#offline--local-data-home).
- Views depend only on their ViewModel.
- ViewModels depend on `DataServiceProtocol` — not on `APIService` directly.
- Unit tests use `MockDataService` (and offline tests use fakes for network/API as described below).

## Auth flow

Firebase manages session state. `AuthManager` publishes `authenticationState` to `VaultTrackerApp`, which switches the root view. If the Firebase auth state listener never runs, `AuthManager` falls back to unauthenticated after 5 seconds. `AuthTokenProvider` (an actor) vends Firebase JWTs to `APIService` for every request, with an automatic retry on 401.

## Environment / backend

| Build   | Environment | Backend                                       |
| ------- | ----------- | --------------------------------------------- |
| DEBUG   | development | `API_HOST` env var (default `localhost:8000`) |
| RELEASE | production  | `https://vaulttracker-api.onrender.com`       |

Switch is compile-time `#if DEBUG` — no source change needed before archiving.

**Real device:** Set `API_HOST = 192.168.x.x:8000` in Xcode scheme env vars; both devices must be on same Wi-Fi.

## Tab structure

| Tab       | View            | SF Symbol            |
| --------- | --------------- | -------------------- |
| Home      | `HomeView`      | `house`              |
| Analytics | `AnalyticsView` | `chart.pie.fill`     |
| FIRE      | `FIREView`      | `flame.fill`         |
| Profile   | `ProfileView`   | `person.crop.circle` |

## Key endpoints

| Operation                     | Method + Path                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------- |
| Dashboard                     | `GET /api/v1/dashboard`                                                                                 |
| Dashboard (household)         | `GET /api/v1/dashboard/household`                                                                       |
| Analytics                     | `GET /api/v1/analytics`                                                                                 |
| Smart transaction             | `POST /api/v1/transactions/smart`                                                                       |
| Price refresh                 | `POST /api/v1/prices/refresh`                                                                           |
| Transactions (enriched)       | `GET /api/v1/transactions`                                                                              |
| Net worth history             | `GET /api/v1/networth/history?period=daily\|weekly\|monthly`                                            |
| Net worth history (household) | `GET /api/v1/networth/history/household?period=…`                                                       |
| Households                    | `GET/POST /api/v1/households`, `GET /api/v1/households/me`, invite/join/leave (see `APIConfiguration`)   |
| FIRE (personal)              | `GET/PUT /api/v1/fire/profile`, `GET /api/v1/fire/projection`                                          |
| FIRE (household shared)       | `GET/PUT /api/v1/households/me/fire-profile`                                                            |

## Design system (Digital Ledger)

- **Spec:** [2026-03-28-digital-ledger-redesign-design.md](../../Documentation/Plans/2026-03-28-digital-ledger-redesign-design.md)
- **Theme:** Dark-only via `.preferredColorScheme(.dark)` on the app root.
- **Tokens:** `VTColors` (including `categoryAccent(_:)`), `VTFonts` in `VTTypography.swift`, `VTComponents` (`VTPrimaryButtonStyle`, `FilterChipStyle`, `.vtSurfaceCard()`).
- **UI tests** resolve views via `accessibilityIdentifier` — keep identifiers stable when changing layout; page objects in `VaultTrackerUITests/PageObjects/` depend on them.

## Where to start (feature work)

| Task                    | Start here                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| New API endpoint        | `API/APIConfiguration.swift`, `API/APIServiceProtocol.swift`, `API/APIService.swift`                               |
| New screen / tab        | `FeatureName/FeatureView.swift` + `FeatureNameViewModel.swift`, tab in `MainView/VaultTrackerApp.swift`            |
| New data operation      | `Managers/DataServiceProtocol.swift`, `Managers/DataService.swift`, test mock                                     |
| Offline cache / queue   | `Managers/Offline/` — see [Offline & local data (Home)](#offline--local-data-home)                                 |
| New domain type         | `Models/`                                                                                                          |
| New API model           | `API/Models/`                                                                                                      |
| New UI test             | `VaultTrackerUITests/PageObjects/`; subclass `BaseTestCase`. Household: `HouseholdSettingsPage`, `HouseholdFlowUITests` |
| Visual / theming         | `DesignSystem/`, `Utils/Extensions.swift`, `MainView/VaultTrackerApp.swift`                                        |

## Offline & local data (Home)

- **Scope (v1):** **Home** only — last-known **personal/household** dashboard, **net worth history** (per period + scope), **smart transaction** create (queue when offline). **`DataService` / `APIService` are unchanged;** coordination lives in **`DataRepository`**. Other tabs use the same `DataService` network behavior as before.
- **`LocalDataStack`:** One SwiftData `ModelContainer`, `CachedDataStore`, `PendingTransactionStore`, `NWPathNetworkMonitor`, `OfflineSyncManager`. `VaultTrackerApp` holds `@StateObject` and passes `dataRepository { authManager.user?.uid }` into `HomeView` / `HomeViewModel`.
- **`OfflineBanner`:** `Custom UI Components/OfflineBanner.swift` — reachability + sync state; `environmentObject` for monitor and `OfflineSyncManager` on the authenticated root.
- **Repository system design:** [VaultTracker System Design.md](../../../Documentation/VaultTracker%20System%20Design.md) §4.2.1. **Feature design:** [2026-04-25-ios-offline-support-design.md](../../Documentation/Plans/2026-04-25-ios-offline-support-design.md).
- **Tests:** `OfflineStoresTests`, `OfflineSyncManagerTests`, `DataRepositoryTests`; `MockAPIService` stubs API surface used by `DataRepository` for net worth and transactions.

## Household & FIRE

- **Flow:** SwiftUI → view models (`HomeViewModel`, `HouseholdSettingsViewModel`, `FIREViewModel`) → **`DataServiceProtocol`** / `DataService` → **`APIService`**. Tests use **`MockDataService`**.
- **Household:** `GET/POST /households`, `GET /households/me`, invite/join/leave, `GET /dashboard/household`, `GET /networth/history/household`. **`GET /households/me`** returns **404** with detail `Not a member of a household` when the user has no household; `fetchHousehold()` returns **`nil`** (not a thrown error).
- **FIRE:** Personal: `GET/PUT /fire/profile`, `GET /fire/projection`. Household (member): `GET/PUT /households/me/fire-profile`. There is **no** household projection API; in household mode the FIRE tab edits shared inputs and does **not** show a combined projection (aligned with web).
- **Analytics on iOS:** `AnalyticsViewModel` uses **`GET /analytics`** only (personal). Household allocation bento is **web-only** in v1.

## Firebase `GoogleService-Info.plist`

Not tracked in git. Copy `GoogleService-Info.plist.example` → `GoogleService-Info.plist` and fill in values from Firebase console (Project settings → Your apps → iOS). CI copies the example to that path before `xcodebuild test`.

If this file was ever committed: **restrict keys** in Google Cloud Console and follow your team's secret-rotation policy.

## Tests

### Unit / integration tests (`VaultTrackerTests/`)

- **Unit tests** use Swift Testing (`@Test`, `#expect`). Examples: `HomeViewModelTests`, `AnalyticsViewModelTests`, `AddAssetFormViewModelTests`, `FIREViewModelTests`, `AuthManagerTests`, `APIServiceTests`, `AuthTokenProviderTests`, household mappers, `APIModelsCodableTests`, **offline:** `OfflineStoresTests`, `OfflineSyncManagerTests`, `DataRepositoryTests`.
- `APIServiceTests` uses `APIService.test_make(session:log:tokenProvider:)` with a stub `URLProtocol` session and per-test `AuthTokenProvider` via `makeDebugProvider()` — avoids cross-suite races with `AuthTokenProvider.shared`.
- `AuthManagerTests` injects `FakeFirebaseAuthBackend` + isolated `NotificationCenter` with short `authListenerTimeoutNanoseconds` for timeout tests.
- **Integration tests** (`APIIntegrationTests`, `HomeViewModelIntegrationTests`, `AddAssetFormViewModelIntegrationTests`) hit a real local API with `DEBUG_AUTH_ENABLED=true`.
- `MockDataService.swift` is the test double for `DataServiceProtocol`.

### UI tests (`VaultTrackerUITests/`)

Page object pattern — each screen has a `struct` in `PageObjects/`:

| Page Object              | Screen                         |
| ------------------------ | ------------------------------ |
| `LoginPage`              | Login                          |
| `HomePage`               | Home tab                       |
| `AddAssetPage`           | Add transaction sheet          |
| `AnalyticsPage`          | Analytics tab                  |
| `ProfilePage`            | Profile tab                    |
| `HouseholdSettingsPage`  | Profile → household settings   |

- BDD naming: `test_given<state>_when<action>_then<outcome>`
- Elements resolved via `accessibilityIdentifier` — do not change identifiers without updating page objects
- Launch argument `-UI-Testing` enables debug auth mode
- UI tests that create data require local API with `DEBUG_AUTH_ENABLED=true` — **not** in the default CI unit-test-only plan

### Verification commands

Run from the **repository root** (parent of `VaultTrackerIOS/`) unless noted.

**SwiftLint** (same as CI; from `VaultTrackerIOS/VaultTracker/`):

```bash
cd VaultTrackerIOS/VaultTracker && swiftlint lint
# optional: swiftlint --fix
```

**Unit tests** (adjust simulator name to match local runtimes; see root `CLAUDE.md` / CI for destination):

```bash
cd VaultTrackerIOS && xcodebuild test -project VaultTracker.xcodeproj -scheme VaultTracker -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VaultTrackerTests
```

Xcode: **Cmd+U** on scheme **VaultTracker** (unit test plan as configured in the project).

**UI / integration** tests that need a live API: run against local or staging API with `DEBUG_AUTH_ENABLED=true` on the API.

## Refactor plan status

| Phase | Description                       | Status  |
| ----- | --------------------------------- | ------- |
| 1     | Point to production               | ✅ Done |
| 2     | Smart transaction endpoint        | ✅ Done |
| 3     | Enriched transaction responses    | ✅ Done |
| 4     | Analytics tab                     | ✅ Done |
| 5     | Price refresh                     | ✅ Done |
| 6     | Period-aggregated net worth chart | ✅ Done |
| 7     | Cleanup                           | ✅ Done |
