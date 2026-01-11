# TODO: Filtered Asset View

## Phase 1: ViewModel Logic

- [x] Update `HomeViewState` to include `selectedFilter: AssetCategory?` and `filteredAssets: [Asset]`.
- [x] Implement `selectFilter(category: AssetCategory?)` function in `HomeViewModel`.

## Phase 2: UI Implementation

- [x] Modify `filterBarView` to include an "All" button and buttons for each `AssetCategory`.
- [x] Implement `aggregatedAssetListView` to display the filtered assets.
- [x] Add conditional logic to `HomeView` to switch between the default and filtered views.

## Phase 3: Finalization

- [x] Test the feature thoroughly.
- [x] Review and refactor code as needed.
