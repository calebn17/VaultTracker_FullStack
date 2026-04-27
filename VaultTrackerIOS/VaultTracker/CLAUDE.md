# VaultTracker iOS App

Portfolio tracker: net worth, asset holdings, analytics, and transaction history backed by the VaultTracker REST API.

> **Architecture, auth flow, environment/backend, tests, endpoints, refactor plan:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Directory Map

```
VaultTracker/
├── DesignSystem/       # Digital Ledger tokens: VTColors, VTFonts (VTTypography.swift), VTComponents
├── MainView/           # App entry point, root TabView (Home, Analytics, FIRE, Profile), auth state switch
├── Login/              # Google sign-in screen
├── Loading/            # Splash screen during Firebase auth check
├── Home/               # Dashboard: net worth, category breakdown, history chart, price refresh
├── AddAssetModal/      # Sheet for recording buy/sell transactions via smart endpoint
├── Analytics/          # Allocation breakdown and gain/loss performance tab
├── Fire/               # FIRE calculator — personal projection vs shared household inputs (no household projection in v1)
├── Profile/            # User info, household settings, sign-out
├── API/                # All networking: URLSession, protocols, models, mappers
├── Managers/           # DataService (app-layer), AuthManager, NetworkService (legacy), Offline/ SwiftData cache + pending queue
├── Models/             # Domain value types (Asset, Transaction, Account, etc.)
├── Custom UI Components/ # Reusable SwiftUI primitives
├── Utils/              # VTLogging / VTLogLive, extensions, UIKit bridges
└── Assets.xcassets
```

Each directory has its own `CLAUDE.md`.

## SwiftLint

```bash
# From VaultTrackerIOS/VaultTracker/ (install once: brew install swiftlint)
swiftlint lint    # same as CI (errors fail; warnings pass)
swiftlint --fix   # autocorrect before committing
```

## Design System (Digital Ledger)

- **Spec:** [`Documentation/Plans/2026-03-28-digital-ledger-redesign-design.md`](../Documentation/Plans/2026-03-28-digital-ledger-redesign-design.md)
- **Theme:** Dark-only via `.preferredColorScheme(.dark)` on root
- **Tokens:** `VTColors` (including `categoryAccent(_:)`), `VTFonts` in `VTTypography.swift`, `VTComponents` (`VTPrimaryButtonStyle`, `FilterChipStyle`, `.vtSurfaceCard()`)
- Keep `accessibilityIdentifier` values stable — UI tests query by these

## Key Files for New Features

| Task                    | Start here                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| New API endpoint        | `API/APIConfiguration.swift`, `API/APIServiceProtocol.swift`, `API/APIService.swift`                               |
| New screen / tab        | Create `FeatureName/FeatureView.swift` + `FeatureNameViewModel.swift`, add tab in `MainView/VaultTrackerApp.swift` |
| New data operation      | `Managers/DataServiceProtocol.swift`, `Managers/DataService.swift`, test mock                                      |
| Offline cache / queue   | `Managers/Offline/` (`OfflinePersistence`, `LocalDataStack`, `CachedDataStore`, `PendingTransactionStore`, `OfflineSyncManager`, `DataRepository` + `NetworkMonitoring` / `NWPathNetworkMonitor`); tests: `OfflineStoresTests`, `OfflineSyncManagerTests`, `DataRepositoryTests`, `MockAPIService` |
| New domain type         | `Models/`                                                                                                          |
| New API model           | `API/Models/`                                                                                                      |
| New UI test             | Add page object in `VaultTrackerUITests/PageObjects/`; subclass `BaseTestCase`. Household flows: `HouseholdSettingsPage`, `HouseholdFlowUITests`. |
| Visual / ledger theming | `DesignSystem/`, `Utils/Extensions.swift`, `MainView/VaultTrackerApp.swift`                                        |

## Household & FIRE (architecture)

- **Flow:** SwiftUI views → view models (`HomeViewModel`, `HouseholdSettingsViewModel`, `FIREViewModel`) → **`DataServiceProtocol`** / `DataService` → **`APIService`** — same layering as the rest of the app; tests use **`MockDataService`**.
- **Household reads/writes:** `GET/POST /households`, `GET /households/me`, invite/join/leave, `GET /dashboard/household`, `GET /networth/history/household`. **`GET /households/me`** returns **404** with detail `Not a member of a household` when the user has no household; `fetchHousehold()` maps that to **`nil`** (not a thrown error).
- **FIRE:** Personal: `GET/PUT /fire/profile`, `GET /fire/projection`. Household (member): `GET/PUT /households/me/fire-profile`. There is **no** household projection endpoint; in household mode the FIRE tab edits shared inputs and **does not** show a combined projection (same contract as web).
- **Analytics:** `AnalyticsViewModel` still uses **`GET /analytics`** only (personal). Household allocation bento is web-only in v1.

### Verify

```bash
# SwiftLint (same as CI path)
cd VaultTrackerIOS/VaultTracker && swiftlint lint
```

- **Unit tests:** Xcode **Cmd+U** with scheme **VaultTracker** (or `xcodebuild test` per root `CLAUDE.md` / CI). Household/FIRE logic: e.g. `FIREViewModelTests`, mapper tests, `MockDataService`.
- **UI tests** (`HouseholdFlowUITests`, etc.): need a **running API** with `DEBUG_AUTH_ENABLED=true`; not in the default CI unit-test-only plan.
