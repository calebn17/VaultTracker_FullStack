# VaultTracker iOS App

Portfolio tracker that shows net worth, asset holdings, analytics, and transaction history backed by the VaultTracker REST API (`https://vaulttracker-api.onrender.com`).

## Directory Map

```
VaultTracker/
├── DesignSystem/       # Digital Ledger tokens: VTColors, VTFonts (VTTypography.swift), VTComponents (button/chip/surface)
├── MainView/           # App entry point, root TabView (Home / Analytics / Profile), auth state switch; forces dark + nav/tab chrome
├── Login/              # Google / Apple sign-in screen
├── Loading/            # Splash screen during Firebase auth check
├── Home/               # Dashboard: net worth, category breakdown, history chart, price refresh
├── AddAssetModal/      # Sheet for recording buy/sell transactions via smart endpoint
├── Analytics/          # Allocation breakdown and gain/loss performance tab
├── Profile/            # User info + sign-out
├── API/                # All networking: URLSession, protocols, models, mappers
├── Managers/           # DataService (app-layer), AuthManager, NetworkService (legacy)
├── Models/             # Domain value types (Asset, Transaction, Account, etc.)
├── Custom UI Components/ # Reusable SwiftUI primitives (CustomButton, CustomTextField)
├── Utils/              # `VTLogging` / `VTLogLive`, extensions, UIKit bridges
└── Assets.xcassets     # Image and color assets
```

Each directory has its own `CLAUDE.md` with feature-specific context.

## Design system (Digital Ledger)

- **Spec:** [Documentation/Plans/2026-03-28-digital-ledger-redesign-design.md](../Documentation/Plans/2026-03-28-digital-ledger-redesign-design.md) — color/type/component rules and screen checklist (view-only; keep `accessibilityIdentifier` values stable).
- **Theme:** Dark-only via `.preferredColorScheme(.dark)` on the root in `VaultTrackerApp`; global `UINavigationBar` / `UITabBar` (and `UISegmentedControl` for the home period picker) are configured there or on first `HomeView` appearance to match `VTColors`.
- **Tokens:** `VTColors` (including `categoryAccent(_:)` for dashboard keys), `VTFonts` in `VTTypography.swift`, reusable styles in `VTComponents` (`VTPrimaryButtonStyle`, `FilterChipStyle`, `SurfaceCardModifier` / `.vtSurfaceCard()`).

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

Firebase manages session state. `AuthManager` publishes `authenticationState` to `VaultTrackerApp`, which switches the root view. `AuthTokenProvider` (an actor) vends Firebase JWTs to `APIService` for every request, with an automatic retry on 401.

## Environment / Backend

- **DEBUG builds** → `development` environment → reads `API_HOST` from Xcode scheme env vars (default: `localhost:8000`)
- **RELEASE builds** → `production` environment → `https://vaulttracker-api.onrender.com`

No manual change needed before archiving — the switch is compile-time (`#if DEBUG`).

## Tab Structure

| Tab | View | SF Symbol |
|-----|------|-----------|
| Home | `HomeView` | `house` |
| Analytics | `AnalyticsView` | `chart.pie.fill` |
| Profile | `ProfileView` | `person.crop.circle` |

## Key Endpoints (current)

| Operation | Method + Path |
|-----------|--------------|
| Dashboard | `GET /api/v1/dashboard` |
| Analytics | `GET /api/v1/analytics` |
| Smart transaction | `POST /api/v1/transactions/smart` |
| Price refresh | `POST /api/v1/prices/refresh` |
| Transactions (enriched) | `GET /api/v1/transactions` |
| Net worth history | `GET /api/v1/networth/history?period=daily\|weekly\|monthly` |

## Tests

### Unit / Integration Tests (`VaultTrackerTests/`)

- **Unit tests** use Swift Testing (`@Test`, `#expect`). ViewModel coverage includes `HomeViewModelTests`, `AnalyticsViewModelTests`, and `AddAssetFormViewModelTests` (validation / request encoding without the network). `AuthManagerTests` injects `FakeFirebaseAuthBackend` + isolated `NotificationCenter` for auth state, debug sign-out, and `.authenticationRequired` behavior. `APIServiceTests` builds the service with `APIService.test_make(session:log:)` (DEBUG-only factory), `URLSession` + stub `URLProtocol`, `VTLoggingSpy`, and `APIServiceTestAuth.withDebugSession` / `AuthTokenProvider.forceTokenRefreshFailure` where needed; the `@Test` methods live in `#if DEBUG` because `isDebugSession` exists only in DEBUG builds.
- **Integration tests** (`APIIntegrationTests`, `HomeViewModelIntegrationTests`, `AddAssetFormViewModelIntegrationTests`) hit a real local API with debug auth — the API server must be running with `DEBUG_AUTH_ENABLED=true`.
- `MockDataService.swift` is the test double for `DataServiceProtocol`; add stubs there when new protocol methods are declared. For analytics VM tests it exposes `analyticsStub`, `analyticsError`, and `fetchAnalyticsCallCount` (mirrors the dashboard / refresh-prices patterns).
- **Inventory** (Swift `@Test` in `VaultTrackerTests/`): mappers, codable, errors, view models, and `AuthManager`; 20 integration-tagged cases. See [Documentation/Plans/2026-03-29-ios-test-plan.md](../Documentation/Plans/2026-03-29-ios-test-plan.md) for the coverage map and CI split (unit vs integration vs UI).

### UI Tests (`VaultTrackerUITests/`)

Tests use a **page object pattern** — each screen has a `struct` in `PageObjects/`:

| Page Object | Screen |
|-------------|--------|
| `LoginPage` | Login screen |
| `HomePage` | Home tab |
| `AddAssetPage` | Add transaction sheet |
| `AnalyticsPage` | Analytics tab |
| `ProfilePage` | Profile tab |

- Tests follow BDD naming: `test_given<state>_when<action>_then<outcome>`.
- Page objects resolve elements with `XCUIApplication.identified(_:)` (`XCUIApplication+Identified.swift`) so SwiftUI controls are found by `accessibilityIdentifier` regardless of XCTest element type.
- Launch argument `-UI-Testing` signals debug auth mode; the app skips real Firebase and uses the debug token.
- UI tests that create data (`seedCashHoldingViaUI`) require the local API server with `DEBUG_AUTH_ENABLED=true` and `DEBUG_AUTH_ENABLED=true`.
- Accessibility identifiers (e.g. `homeScrollView`, `netWorthTitleText`, `addTransactionButton`) are the stable query targets — do not change them without updating the matching page object.

Run UI tests via **Xcode → Product → Test** (select `VaultTrackerUITests` scheme). They do not run in CI without a live local backend.

## Key Files for New Features

| Task | Start here |
|------|-----------|
| New API endpoint | `API/APIConfiguration.swift`, `API/APIServiceProtocol.swift`, `API/APIService.swift` |
| New screen / tab | Create `FeatureName/FeatureView.swift` + `FeatureNameViewModel.swift`, add tab in `MainView/VaultTrackerApp.swift` |
| New data operation | `Managers/DataServiceProtocol.swift`, `Managers/DataService.swift`, test mock |
| New domain type | `Models/` |
| New API model | `API/Models/` |
| New UI test | Add page object in `VaultTrackerUITests/PageObjects/`; add cases in the matching `*UITests.swift` (subclass `BaseTestCase` for shared `launchApp` / `loginWithDebug` / `seedCashHoldingViaUI`) |
| Visual / ledger theming | `DesignSystem/`, `Utils/Extensions.swift` (`Color(hex:)`), `MainView/VaultTrackerApp.swift`, then feature views (Home, Add Asset, Analytics, Profile, etc.) |

## Refactor Plan Status

See `Documentation/Vault Tracker - iOS Refactor Plan.md` for the full spec.

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Point to production | ✅ Done (compile-time `#if DEBUG`) |
| 2 | Smart transaction endpoint | ✅ Done |
| 3 | Enriched transaction responses | ✅ Done |
| 4 | Analytics tab | ✅ Done |
| 5 | Price refresh | ✅ Done |
| 6 | Period-aggregated net worth chart | ✅ Done |
| 7 | Cleanup | Done (dead API + mapper removed; integration tests use smart create) |
