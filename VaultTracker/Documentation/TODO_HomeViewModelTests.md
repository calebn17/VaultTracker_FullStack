# Test Plan for `HomeViewModel`

This document outlines the test cases for the `HomeViewModel` to ensure its logic is robust and to prevent future regressions.

### Mocking Dependencies

To test the `HomeViewModel` in isolation, a mock version of `DataService` will be created. This mock will allow us to control the data (transactions, assets, prices) that the view model consumes, enabling predictable and repeatable tests.

---

### 1. Initial Data Loading & State Calculation

*   **Goal**: Ensure that when the view model loads, it correctly calculates all total values and groups the assets.
*   **Scenario**:
    *   **Given**: A mock `DataService` that provides a standard set of transactions and assets (e.g., some stocks, some crypto, some cash).
    *   **When**: `loadData()` is called.
    *   **Expect**:
        *   `viewState.totalNetworthValue` is the correct sum of all assets.
        *   `viewState.cryptoTotalValue`, `viewState.stocksTotalValue`, etc., are all correct.
        *   The `groupedAssetHoldings` (e.g., `cryptoGroupedAssetHoldings`) are structured correctly, with assets properly grouped under the right account.

### 2. Saving Transactions

*   **Goal**: Verify that adding new transactions correctly updates the app's state.
*   **Scenario A: Transaction for a NEW Asset**
    *   **Given**: An initial state.
    *   **When**: `onSave()` is called for an asset that doesn't exist yet (e.g., buying "AAPL" for the first time).
    *   **Expect**: A new `Asset` is created, and the view model's total values are updated.
*   **Scenario B: Transaction for an EXISTING Asset**
    *   **Given**: The view model already has an "AAPL" asset.
    *   **When**: `onSave()` is called for another "AAPL" purchase.
    *   **Expect**: The *quantity* of the existing "AAPL" asset is increased, but no new asset is created.

### 3. Price Update Logic

*   **Goal**: Confirm that the `totalValue` of holdings is updated when new market prices are available.
*   **Scenario**:
    *   **Given**: The view model has grouped holdings calculated from their original purchase prices.
    *   Our mock `DataService` then reports a *new, higher price* for a specific stock.
    *   **When**: The price update logic runs.
    *   **Expect**:
        *   The `totalValue` for that stock in the `groupedAssetHoldings` is recalculated (`new price * quantity`).
        *   The value of assets like `.cash` (which don't have market prices) remains unchanged.

### 4. Grouping Logic for Different Asset Types

*   **Goal**: Ensure that assets are grouped correctly, especially those without a `symbol`.
*   **Scenario**:
    *   **Given**: Transactions for two different cash accounts (e.g., "Chase Savings" and "Wells Fargo Checking").
    *   **When**: The grouping logic runs.
    *   **Expect**: The `cashGroupedAssetHoldings` shows two distinct entries, one for each account, correctly using the asset's `name` for grouping.

### 5. UI Filtering Logic

*   **Goal**: Make sure the category filters work as expected.
*   **Scenario**:
    *   **Given**: A state with assets in every category.
    *   **When**: `selectFilter(category: .crypto)` is called.
    *   **Expect**: `viewState.filteredAssets` contains *only* the crypto assets.
    *   **When**: `selectFilter(category: nil)` is called afterwards.
    *   **Expect**: `viewState.filteredAssets` is empty.
