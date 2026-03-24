# PRD: Filtered Asset View

## 1. Overview

The Filtered Asset View feature provides users with a new way to visualize their holdings on the home screen. Instead of grouping assets by account, this feature allows users to filter their portfolio by a specific `AssetCategory` (e.g., Crypto, Stocks, Real Estate) and see a simple, aggregated list of all assets within that category. This gives users a clear, consolidated view of their total holdings for each asset type, independent of the accounts they are held in.

## 2. Key Features & Requirements

### User-Facing Features

-   **Filter Bar:** The existing filter bar in the `HomeView` will be repurposed. It will display a button for each `AssetCategory` and an "All" button to return to the default overview.
-   **Aggregated Asset List:** When a category is selected from the filter bar, the main content area of the `HomeView` will display a flat list of all assets belonging to that category.
-   **List Item Details:** Each item in the aggregated list will display:
    -   Asset Name and Symbol (e.g., "Bitcoin (BTC)")
    -   Total Current Value (e.g., "$50,000.00")
    -   Total Quantity (e.g., "0.5 coins" or "10 shares")

### Technical Requirements

-   The feature must use the existing `Asset` SwiftData model as the source of truth for the aggregated view.
-   No new data models should be required.
-   The state for the selected filter and the filtered data must be managed within the `HomeViewModel`.
-   The UI must be implemented in `HomeView.swift` by conditionally rendering either the default account-grouped view or the new aggregated asset list.

## 3. Implementation Plan

### Phase 1: ViewModel Logic (`HomeViewModel.swift`)

1.  **Update `HomeViewState`:**
    -   Modify the `selectedFilter` property from `String` to `AssetCategory?`. A `nil` value will represent the default "All" or "Overview" state.
    -   Add a new property `filteredAssets: [Asset] = []` to hold the data for the view.
2.  **Create State-Update Function:**
    -   Implement a public function `selectFilter(category: AssetCategory?)`.
    -   This function will update `viewState.selectedFilter` with the chosen category.
    -   It will then populate `viewState.filteredAssets` by filtering the main `self.assets` array based on the selected category. If the category is `nil`, `filteredAssets` will be cleared.

### Phase 2: UI Implementation (`HomeView.swift`)

1.  **Enhance `filterBarView`:**
    -   Update the `ForEach` to iterate over `AssetCategory.allCases` to create the filter buttons.
    -   Add an "All" button.
    -   The action for each button will call `viewModel.selectFilter(category:)`.
    -   Button styling will be updated to reflect the active filter stored in `viewModel.viewState.selectedFilter`.
2.  **Create `aggregatedAssetListView`:**
    -   Implement a new `@ViewBuilder` function that takes `[Asset]` as input.
    -   It will iterate over the provided assets and render a row for each, displaying the name/symbol, value, and quantity.
3.  **Conditionally Render Main Content:**
    -   In the `HomeView` body, use an `if viewModel.viewState.selectedFilter == nil` check.
    -   If `true`, display the existing account-grouped `assetListSection` view.
    -   If `false`, display the new `aggregatedAssetListView`, passing in `viewModel.viewState.filteredAssets`.
