# VaultTracker iOS App

Portfolio tracker: net worth, asset holdings, analytics, and transaction history backed by the VaultTracker REST API.

> **Architecture, auth flow, environment/backend, tests, endpoints, refactor plan:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Directory Map

```
VaultTracker/
├── DesignSystem/       # Digital Ledger tokens: VTColors, VTFonts (VTTypography.swift), VTComponents
├── MainView/           # App entry point, root TabView, auth state switch
├── Login/              # Google sign-in screen
├── Loading/            # Splash screen during Firebase auth check
├── Home/               # Dashboard: net worth, category breakdown, history chart, price refresh
├── AddAssetModal/      # Sheet for recording buy/sell transactions via smart endpoint
├── Analytics/          # Allocation breakdown and gain/loss performance tab
├── Profile/            # User info + sign-out
├── API/                # All networking: URLSession, protocols, models, mappers
├── Managers/           # DataService (app-layer), AuthManager, NetworkService (legacy)
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
| New domain type         | `Models/`                                                                                                          |
| New API model           | `API/Models/`                                                                                                      |
| New UI test             | Add page object in `VaultTrackerUITests/PageObjects/`; subclass `BaseTestCase`                                     |
| Visual / ledger theming | `DesignSystem/`, `Utils/Extensions.swift`, `MainView/VaultTrackerApp.swift`                                        |
