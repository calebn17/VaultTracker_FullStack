# Home

Main dashboard screen. Shows net worth, asset breakdown by category, per-asset holdings, the net worth history chart, and toolbar actions for price refresh and adding transactions.

## Files

| File | Role |
|------|------|
| `HomeView.swift` | SwiftUI dashboard UI |
| `HomeViewModel.swift` | State management, API orchestration |
| `HomeViewWrapper.swift` | Thin wrapper that owns the `@StateObject` so previews stay clean |
| `NetWorthChartView.swift` | Line chart rendered from `[NetWorthSnapshot]` |

## State — `HomeViewState`

A plain struct that holds all display values sourced from the dashboard API:
- Per-category total values (`cryptoTotalValue`, etc.) and grouped holdings arrays
- `totalNetworthValue`
- `selectedFilter` — the active category chip (`nil` = show all)
- `filteredAssets` — the holdings list shown when a filter is active
- `isLoading`, `errorMessage`

Additional `@Published` properties on the ViewModel:
- `selectedPeriod: APINetWorthPeriod` — controls chart granularity (daily/weekly/monthly)
- `isRefreshingPrices: Bool` — disables the refresh button during in-flight price refresh

## Data Flow

```
.task { viewModel.loadData() }
    └─> DataService.fetchDashboard()
        └─> DashboardMapper.toViewState(_:)  →  HomeViewState
    └─> DataService.fetchNetWorthHistory(period: selectedPeriod)  →  snapshots
```

Pull-to-refresh calls `loadData()` again. The active filter is re-applied after each reload so the selected category chip survives a refresh.

## Adding a Transaction (`onSave`)

`onSave(smartRequest:)` takes an `APISmartTransactionCreateRequest` built by `AddAssetFormViewModel.save()`:
1. Calls `DataService.createSmartTransaction(_:)` → `POST /transactions/smart`
2. Backend resolves or creates the account and asset server-side.
3. Calls `loadData()` to refresh the dashboard.

No client-side asset/account resolution. The old multi-step flow (resolve asset → create asset → create transaction) has been removed.

## Refreshing Prices (`refreshPrices`)

Calls `DataService.refreshPrices()` → `POST /api/v1/prices/refresh`. On success, calls `loadData()` to show updated values. The "Refresh Prices" toolbar button is disabled while `isRefreshingPrices == true`.

## Net Worth Chart Period (`selectNetWorthPeriod`)

`selectNetWorthPeriod(_:)` updates `selectedPeriod` and fires `rebuildHistoricalSnapshots()` via a `Task`. A `Picker(.segmented)` in `HomeView` provides Daily / Weekly / Monthly selection. `rebuildHistoricalSnapshots()` always passes `selectedPeriod` to `fetchNetWorthHistory(period:)`.

## Filter Logic (`selectFilter`)

`selectFilter(category:)` sets `viewState.selectedFilter` and populates `viewState.filteredAssets` from the matching holdings array. Passing `nil` clears the filter and shows the full category list.

## Net Worth Chart

`NetWorthChartView` receives `snapshots: [NetWorthSnapshot]` as a plain array — it is a pure display component with no ViewModel of its own.
