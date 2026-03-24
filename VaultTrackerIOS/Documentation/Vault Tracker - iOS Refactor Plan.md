# VaultTracker iOS Refactor — Plan

> **Purpose:** AI-agent consumable spec for refactoring the iOS app to consume Backend 2.0 endpoints. Read the [iOS Context](Vault%20Tracker%20-%20iOS%20Context.md) and [Backend 2.0 Spec](Vault%20Tracker%20-%20Backend%202.0%20Spec.md) first.

---

## Context

Backend 2.0 is fully deployed (Phases 1-4 complete): PostgreSQL on Neon, Firebase JWT verification, smart transaction endpoint, enriched responses, analytics, price service, caching, and period-aggregated net worth history. The iOS app still points at `localhost:8000` and does asset/account resolution client-side. This refactor updates the iOS app to use the production backend and consume all new Backend 2.0 capabilities.

**iOS project root:** `/Users/calebngai/Desktop/iOS Development/VaultTracker/VaultTracker/VaultTracker/`

---

## Phase 1: Point to Production

### 1.1 Update base URL
**File:** `API/APIConfiguration.swift`
- Set `.production` case to `https://vaulttracker-api.onrender.com`
- Switch `static let environment: APIEnvironment = .production`
- Keep `.development` case as-is for local dev

### 1.2 Verify existing flows work
- Build & run against production
- Confirm login, dashboard, add transaction, net worth chart all work unchanged

---

## Phase 2: Smart Transaction Endpoint

**Goal:** Replace the multi-step client-side flow (resolve account -> resolve/create asset -> create transaction) with a single `POST /transactions/smart` call.

### 2.1 Add `APISmartTransactionCreateRequest` model
**File:** `API/Models/APITransactionModels.swift` (add to existing file)
```swift
struct APISmartTransactionCreateRequest: Codable {
    let transactionType: String
    let category: String
    let assetName: String
    let symbol: String?
    let quantity: Double
    let pricePerUnit: Double
    let accountName: String
    let accountType: String
    let date: Date?
}
```
With CodingKeys mapping to snake_case (`transaction_type`, `asset_name`, `price_per_unit`, `account_name`, `account_type`).

### 2.2 Add endpoint constant
**File:** `API/APIConfiguration.swift`
- Add `static let smartTransaction = "\(apiVersion)/transactions/smart"` to `Endpoints`

### 2.3 Add API method
**File:** `API/APIServiceProtocol.swift` — add `func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws -> APITransactionResponse`

**File:** `API/APIService.swift` — implement the POST call to the smart endpoint

### 2.4 Add DataService method
**File:** `Managers/DataServiceProtocol.swift` — add `func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws`

**File:** `Managers/DataService.swift` — implement by delegating to `api.createSmartTransaction()`; no need to return a full domain `Transaction` since `HomeViewModel` reloads dashboard after save anyway

### 2.5 Simplify `HomeViewModel.onSave()`
**File:** `Home/HomeViewModel.swift`

**Current flow (lines 79-141):**
1. Collects all holdings from viewState
2. Matches by symbol or name to find existing asset ID
3. If no match, creates asset via `POST /assets`
4. Builds `APITransactionCreateRequest` with resolved `assetId` + `accountId`
5. Calls `dataService.createTransaction()`

**New flow:**
1. Build `APISmartTransactionCreateRequest` from the `Transaction` value object
2. Call `dataService.createSmartTransaction()`
3. Reload dashboard

This eliminates ~60 lines of resolution logic.

### 2.6 Simplify `AddAssetFormViewModel`
**File:** `AddAssetModal/AddAssetFormViewModel.swift`

The `getOrCreateAccount()` method (lines 150-170) fetches all accounts and resolves by name. With the smart endpoint, the backend does this. The form VM just needs to pass `accountName` and `accountType` strings — no account resolution needed.

`save()` can return a simpler value type (or just a struct with the raw form fields) instead of a full `Transaction` domain model with a resolved `Account`.

### 2.7 Update `MockDataService`
**File:** `VaultTrackerTests/MockDataService.swift` — add stub for `createSmartTransaction()`

---

## Phase 3: Enriched Transaction Responses

**Goal:** `GET /transactions` now returns `EnrichedTransactionResponse` with inline `asset` and `account` objects. Eliminate the 3-way parallel fetch in `DataService.fetchAllTransactions()`.

### 3.1 Add enriched response model
**File:** `API/Models/APITransactionModels.swift` (add to existing file)
```swift
struct APIAssetSummary: Codable { id, name, symbol, category }
struct APIAccountSummary: Codable { id, name, accountType }
struct APIEnrichedTransactionResponse: Codable {
    id, userId, assetId, accountId, transactionType, quantity, pricePerUnit, totalValue, date
    asset: APIAssetSummary
    account: APIAccountSummary
}
```

### 3.2 Update `APIServiceProtocol.fetchTransactions()`
**File:** `API/APIServiceProtocol.swift`
- Change return type from `[APITransactionResponse]` to `[APIEnrichedTransactionResponse]`

**File:** `API/APIService.swift` — update the decode type

### 3.3 Simplify `DataService.fetchAllTransactions()`
**File:** `Managers/DataService.swift`

**Current (lines 39-56):** 3 parallel fetches (transactions + assets + accounts), then joins via `TransactionMapper.toDomain()`.

**New:** Single fetch. Map `APIEnrichedTransactionResponse` directly to domain `Transaction` using inline asset/account data. No parallel fetches needed.

### 3.4 Update `TransactionMapper`
**File:** `API/Mappers/TransactionMapper.swift`
- Add a new mapping function: `toDomain(_ response: APIEnrichedTransactionResponse) -> Transaction`
- Old mapper methods can stay for backward compatibility or be removed

### 3.5 Clean up unused methods
After this change, `APIService.fetchAssets()` and `APIService.fetchAccounts()` are no longer called by `fetchAllTransactions()`. They may still be needed elsewhere — check before removing.

---

## Phase 4: Analytics

**Goal:** Add a new analytics tab showing allocation breakdown and gain/loss performance.

### 4.1 Add API models
**New file:** `API/Models/APIAnalyticsModels.swift`
```swift
struct APIAllocationEntry: Codable { value: Double, percentage: Double }
struct APIPerformanceBlock: Codable { totalGainLoss, totalGainLossPercent, costBasis, currentValue }
struct APIAnalyticsResponse: Codable {
    allocation: [String: APIAllocationEntry]
    performance: APIPerformanceBlock
}
```

### 4.2 Add endpoint + API method
**File:** `API/APIConfiguration.swift` — add `static let analytics = "\(apiVersion)/analytics"`
**File:** `API/APIServiceProtocol.swift` — add `func fetchAnalytics() async throws -> APIAnalyticsResponse`
**File:** `API/APIService.swift` — implement GET call

### 4.3 Add DataService method
**Files:** `DataServiceProtocol.swift`, `DataService.swift` — add `fetchAnalytics()`

### 4.4 Build Analytics UI
**New files:**
- `Analytics/AnalyticsView.swift` — allocation pie/bar chart + performance summary
- `Analytics/AnalyticsViewModel.swift` — fetches analytics, maps to view state

### 4.5 Add tab
**File:** `MainView/VaultTrackerApp.swift` — add Analytics tab to the TabView (third tab after Home and Profile)

---

## Phase 5: Price Refresh

**Goal:** Add ability to refresh asset prices from the backend's CoinGecko/Alpha Vantage integration.

### 5.1 Add API models
**New file:** `API/Models/APIPriceModels.swift`
```swift
struct APIPriceRefreshResult: Codable {
    updated: [APIPriceUpdate]
    skipped: [String]
    errors: [APIPriceError]
}
struct APIPriceUpdate: Codable { assetId, symbol, oldValue, newValue, price }
struct APIPriceError: Codable { symbol, error }
```

### 5.2 Add endpoint + API method
**File:** `API/APIConfiguration.swift` — add `static let priceRefresh = "\(apiVersion)/prices/refresh"`
**File:** `API/APIServiceProtocol.swift` — add `func refreshPrices() async throws -> APIPriceRefreshResult`
**File:** `API/APIService.swift` — implement POST call

### 5.3 Add DataService method
**Files:** `DataServiceProtocol.swift`, `DataService.swift` — add `refreshPrices()`

### 5.4 Add refresh button to HomeView
**File:** `Home/HomeView.swift` — add a "Refresh Prices" toolbar button or pull-to-refresh enhancement

**File:** `Home/HomeViewModel.swift` — add `refreshPrices()` method that calls the service then reloads the dashboard

---

## Phase 6: Period-Aggregated Net Worth History

**Goal:** Use the backend's now-functional `period` parameter for net worth chart granularity.

### 6.1 Add period selector to chart
**File:** `Home/HomeView.swift` or `Home/NetWorthChartView.swift` — add a segmented control (Daily / Weekly / Monthly)

### 6.2 Update HomeViewModel
**File:** `Home/HomeViewModel.swift`
- Add `@Published var selectedPeriod: APINetWorthPeriod = .daily`
- Update `rebuildHistoricalSnapshots()` to pass the selected period
- The existing `fetchNetWorthHistory(period:)` already supports the parameter — just needs to be wired to UI

---

## Phase 7: Cleanup

### 7.1 Remove dead code
- `HomeViewModel.onSave()` old resolution logic (replaced by smart endpoint)
- `AddAssetFormViewModel.getOrCreateAccount()` (replaced by smart endpoint)
- Unused `APIService.fetchAsset(id:)` if no longer called
- Old `TransactionMapper` overloads that took separate asset/account dictionaries

### 7.2 Update `DataService.createTransaction()`
The old `createTransaction()` method did parallel fetches to resolve the domain model. If nothing calls it after the smart endpoint migration, remove it. If the old `POST /transactions` endpoint is still needed for edge cases, keep it.

### 7.3 Update MockDataService & tests
**File:** `VaultTrackerTests/MockDataService.swift` — add stubs for all new protocol methods
**Files:** `HomeViewModelTests.swift`, `HomeViewModelIntegrationTests.swift`, `AddAssetFormViewModelIntegrationTests.swift` — update to test new flows

---

## Implementation Todo List

### Phase 1: Point to Production
- [x] **1.1** Update `APIConfiguration.swift` — set `.production` to `https://vaulttracker-api.onrender.com`, switch `environment` to `.production`
- [ ] **1.2** Build & run — verify login, dashboard, add transaction, net worth chart all work against production

### Phase 2: Smart Transaction Endpoint
- [x] **2.1** Add `APISmartTransactionCreateRequest` model to `API/Models/APITransactionModels.swift` with snake_case CodingKeys
- [x] **2.2** Add `smartTransaction` endpoint constant to `APIConfiguration.swift`
- [x] **2.3** Add `createSmartTransaction()` to `APIServiceProtocol.swift` + implement in `APIService.swift`
- [x] **2.4** Add `createSmartTransaction()` to `DataServiceProtocol.swift` + implement in `DataService.swift`
- [x] **2.5** Rewrite `HomeViewModel.onSave()` — replace ~60 lines of asset/account resolution with single smart endpoint call
- [x] **2.6** Simplify `AddAssetFormViewModel.save()` — remove `getOrCreateAccount()`, return raw form fields instead of resolved `Transaction`
- [x] **2.7** Add `createSmartTransaction()` stub to `MockDataService.swift`
- [ ] **2.8** Test — add transaction for new asset + new account -> verify both auto-created, dashboard updates

### Phase 3: Enriched Transaction Responses
- [x] **3.1** Add `APIAssetSummary`, `APIAccountSummary`, `APIEnrichedTransactionResponse` models to `APITransactionModels.swift`
- [x] **3.2** Update `fetchTransactions()` return type in `APIServiceProtocol.swift` to `[APIEnrichedTransactionResponse]`; update `APIService.swift` decode
- [x] **3.3** Simplify `DataService.fetchAllTransactions()` — single fetch instead of 3 parallel fetches + join
- [x] **3.4** Add `toDomain(_ response: APIEnrichedTransactionResponse)` to `TransactionMapper.swift`
- [x] **3.5** Check if `fetchAssets()` / `fetchAccounts()` / `fetchAsset(id:)` are still needed elsewhere; remove if unused
- [ ] **3.6** Test — transaction list displays asset name, symbol, account inline

### Phase 4: Analytics Tab
- [x] **4.1** Create `API/Models/APIAnalyticsModels.swift` — `APIAllocationEntry`, `APIPerformanceBlock`, `APIAnalyticsResponse`
- [x] **4.2** Add `analytics` endpoint constant to `APIConfiguration.swift`
- [x] **4.3** Add `fetchAnalytics()` to `APIServiceProtocol.swift` + implement in `APIService.swift`
- [x] **4.4** Add `fetchAnalytics()` to `DataServiceProtocol.swift` + implement in `DataService.swift`
- [x] **4.5** Create `Analytics/AnalyticsViewModel.swift` — fetch analytics, map to view state
- [x] **4.6** Create `Analytics/AnalyticsView.swift` — allocation chart + performance summary (gain/loss, cost basis, current value)
- [x] **4.7** Add Analytics tab to `VaultTrackerApp.swift` TabView (3rd tab)
- [x] **4.8** Add `fetchAnalytics()` stub to `MockDataService.swift`
- [ ] **4.9** Test — analytics tab shows correct allocation % and gain/loss numbers

### Phase 5: Price Refresh
- [x] **5.1** Create `API/Models/APIPriceModels.swift` — `APIPriceRefreshResult`, `APIPriceUpdate`, `APIPriceError`
- [x] **5.2** Add `priceRefresh` endpoint constant to `APIConfiguration.swift`
- [x] **5.3** Add `refreshPrices()` to `APIServiceProtocol.swift` + implement in `APIService.swift`
- [x] **5.4** Add `refreshPrices()` to `DataServiceProtocol.swift` + implement in `DataService.swift`
- [x] **5.5** Add `refreshPrices()` method to `HomeViewModel.swift` — calls service then reloads dashboard
- [x] **5.6** Add "Refresh Prices" toolbar button to `HomeView.swift`
- [x] **5.7** Add `refreshPrices()` stub to `MockDataService.swift`
- [ ] **5.8** Test — tap refresh -> crypto/stock values update from CoinGecko/Alpha Vantage

### Phase 6: Period-Aggregated Net Worth
- [x] **6.1** Add period segmented control (Daily / Weekly / Monthly) to `HomeView.swift` or `NetWorthChartView.swift`
- [x] **6.2** Add `@Published var selectedPeriod` to `HomeViewModel.swift`, wire `rebuildHistoricalSnapshots()` to pass it
- [ ] **6.3** Test — toggle period -> chart re-aggregates correctly

### Phase 7: Cleanup
- [x] **7.1** Remove `HomeViewModel.onSave()` old resolution logic (replaced by smart endpoint in 2.5)
- [x] **7.2** Remove `AddAssetFormViewModel.getOrCreateAccount()` (replaced in 2.6)
- [x] **7.3** Remove unused `APIService.fetchAsset(id:)` if no longer called
- [x] **7.4** Remove old `TransactionMapper` overloads that took separate asset/account dictionaries
- [x] **7.5** Remove or keep old `DataService.createTransaction()` — remove if nothing calls it post-migration _(removed `APIService.createTransaction` / `APITransactionCreateRequest`; `DataService` never exposed `createTransaction`.)_
- [x] **7.6** Update all test files — `HomeViewModelTests`, `HomeViewModelIntegrationTests`, `AddAssetFormViewModelIntegrationTests`
- [ ] **7.7** Final build + full test pass _(serial runs: OK. Parallel integration runs: see **Integration tests: parallel vs serial** under Verification — revisit.)_

---

## Verification

1. Build & run against production Render URL
2. Login with Google -> dashboard loads
3. Add transaction via smart endpoint -> asset + account auto-created, dashboard updates
4. View transaction list -> enriched responses show asset name + account inline
5. Open Analytics tab -> allocation percentages + gain/loss display
6. Tap "Refresh Prices" -> crypto/stock prices update from CoinGecko/Alpha Vantage
7. Toggle net worth chart period (Daily/Weekly/Monthly) -> chart re-aggregates
8. Run existing unit tests + integration tests -> all pass
9. Verify old `POST /transactions` endpoint still works (backward compat) for any remaining callers

### Integration tests: parallel vs serial

Unit tests and integration tests **pass when run serially**. **Some integration tests fail under parallel test execution** (multiple simulators / concurrent workers), likely due to **shared backend state** (e.g. `clearAllData`, debug auth, single user) and **cross-test concurrency** rather than app code bugs. **Revisit later:** per-worker isolation, stronger test ordering, or restricting integration suites to a serialized test plan / single worker.

---

## Files Modified

| File | Change |
|------|--------|
| `API/APIConfiguration.swift` | Production URL + new endpoint constants |
| `API/APIServiceProtocol.swift` | New methods: smart transaction, analytics, prices, enriched transactions |
| `API/APIService.swift` | Implement new API calls |
| `API/Models/APITransactionModels.swift` | Smart request + enriched response models |
| `Managers/DataServiceProtocol.swift` | New methods matching API additions |
| `Managers/DataService.swift` | Implement new data service methods, simplify fetchAllTransactions |
| `Home/HomeViewModel.swift` | Simplify onSave, add refreshPrices, add selectedPeriod |
| `Home/HomeView.swift` | Refresh button, period selector |
| `AddAssetModal/AddAssetFormViewModel.swift` | Remove getOrCreateAccount, simplify save |
| `API/Mappers/TransactionMapper.swift` | Add enriched response mapper |
| `MainView/VaultTrackerApp.swift` | Add Analytics tab |

## Files Created

| File | Purpose |
|------|---------|
| `API/Models/APIAnalyticsModels.swift` | Analytics response types |
| `API/Models/APIPriceModels.swift` | Price refresh response types |
| `Analytics/AnalyticsView.swift` | Analytics tab UI |
| `Analytics/AnalyticsViewModel.swift` | Analytics tab state management |
