# Home — System Design

## State (`HomeViewState`)

A plain struct holding all display values from the dashboard API:

- Per-category total values (`cryptoTotalValue`, etc.) and grouped holdings arrays
- `totalNetworthValue`
- `selectedFilter` — active category chip (`nil` = show all)
- `filteredAssets` — holdings list shown when a filter is active
- `isLoading`, `errorMessage`

Additional `@Published` on ViewModel:

- `selectedPeriod: APINetWorthPeriod` — chart granularity (daily/weekly/monthly)
- `isRefreshingPrices: Bool` — disables refresh button during in-flight price refresh

## Data Flow

```
.task { viewModel.loadData() }
    └─> DataService.fetchDashboard()
        └─> DashboardMapper.toViewState(_:)  →  HomeViewState
    └─> DataService.fetchNetWorthHistory(period: selectedPeriod)  →  snapshots
```

Pull-to-refresh calls `loadData()` again. Active filter is re-applied after each reload.

## Key Behaviors

- **Modal:** `shouldPresentSheet` controls sheet presentation; `presentAddSheet()` / `dismissAddSheet()` toggle it.
- **Add transaction (`onSave`):** Takes `APISmartTransactionCreateRequest` from `AddAssetFormViewModel.save()`, posts to `POST /transactions/smart`, then calls `loadData()`.
- **Price refresh:** Calls `POST /api/v1/prices/refresh`, then `loadData()`. Button disabled while `isRefreshingPrices == true`.
- **Period selector:** `selectNetWorthPeriod(_:)` updates `selectedPeriod` and fires `rebuildHistoricalSnapshots()`. `Picker(.segmented)` provides Daily/Weekly/Monthly.
- **Filter:** `selectFilter(category:)` sets `selectedFilter` and populates `filteredAssets`. Passing `nil` clears the filter.
- **Clear data:** `clearData()` calls `DELETE /api/v1/users/me/data`, then resets `viewState` and `snapshots` to empty. Requires confirmation before calling from UI.
- **`NetWorthChartView`:** Pure display component — receives `snapshots: [NetWorthSnapshot]`, no ViewModel.
