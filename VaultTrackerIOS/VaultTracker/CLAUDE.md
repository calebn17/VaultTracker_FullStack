# VaultTracker iOS App

Portfolio tracker that shows net worth, asset holdings, analytics, and transaction history backed by the VaultTracker REST API (`https://vaulttracker-api.onrender.com`).

## Directory Map

```
VaultTracker/
├── MainView/           # App entry point, root TabView (Home / Analytics / Profile), auth state switch
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
├── Utils/              # Extensions (Double formatting), UIKit bridges
└── Assets.xcassets     # Image and color assets
```

Each directory has its own `CLAUDE.md` with feature-specific context.

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

## Key Files for New Features

| Task | Start here |
|------|-----------|
| New API endpoint | `API/APIConfiguration.swift`, `API/APIServiceProtocol.swift`, `API/APIService.swift` |
| New screen / tab | Create `FeatureName/FeatureView.swift` + `FeatureNameViewModel.swift`, add tab in `MainView/VaultTrackerApp.swift` |
| New data operation | `Managers/DataServiceProtocol.swift`, `Managers/DataService.swift`, test mock |
| New domain type | `Models/` |
| New API model | `API/Models/` |

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
| 7 | Cleanup | Ongoing |
