# TODO: API Implementation - iOS Client Integration

## Phase 1: API Client Layer

### 1.1 Configuration & Setup
- [x] Create `APIConfiguration.swift` with base URL and endpoint definitions
- [x] Add environment-based configuration (development/staging/production)
- [x] Define API version constant (`/api/v1`)
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 1.2 API Response Models
- [x] Create `APIDashboardResponse.swift` matching dashboard endpoint response
- [x] Create `APIAccountModels.swift` (response + request models)
- [x] Create `APIAssetModels.swift` (response + request models)
- [x] Create `APITransactionModels.swift` (response + request models)
- [x] Create `APINetWorthHistoryResponse.swift`
- [x] Create `APIErrorResponse.swift` for error handling
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 1.3 APIService Implementation
- [x] Create `APIServiceProtocol.swift` defining all API operations
- [x] Create `APIService.swift` implementing the protocol
- [x] Implement dashboard fetch method
- [x] Implement account CRUD methods
- [x] Implement asset fetch methods
- [x] Implement transaction CRUD methods
- [x] Implement net worth history fetch method
- [x] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 1.4 Authentication Integration
- [ ] Create `AuthTokenProvider.swift` to retrieve Firebase JWT token
- [ ] Modify `NetworkService` to accept dynamic authorization headers
- [ ] Implement token refresh on 401 responses
- [ ] Add auto-logout on persistent authentication failures
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 1.5 Error Handling
- [ ] Create `APIError.swift` with specific error cases
- [ ] Implement error mapping from HTTP status codes
- [ ] Add user-friendly error message generation
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Phase 2: Model Mapping Layer

### 2.1 Domain Model Updates
- [ ] Review existing `Asset` model for API compatibility
- [ ] Review existing `Account` model for API compatibility
- [ ] Review existing `Transaction` model for API compatibility
- [ ] Add `id` property mapping to existing models (UUID handling)
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 2.2 Mappers
- [ ] Create `DashboardMapper.swift` to convert API response to `HomeViewState`
- [ ] Create `AccountMapper.swift` for Account conversions
- [ ] Create `AssetMapper.swift` for Asset conversions
- [ ] Create `TransactionMapper.swift` for Transaction conversions
- [ ] Handle date format conversions (ISO8601)
- [ ] Handle category/type enum mappings
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Phase 3: DataService Refactoring

### 3.1 Dependency Injection
- [ ] Add `APIService` as dependency in `DataService`
- [ ] Create `DataServiceProtocol` if not exists
- [ ] Update `DataService` initializer
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 3.2 Transaction Operations
- [ ] Replace `addTransaction()` with API call + local update
- [ ] Replace `fetchAllTransactions()` with API call
- [ ] Replace `deleteTransaction()` with API call
- [ ] Remove `deleteAllTransactions()` or convert to API batch operation
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 3.3 Asset Operations
- [ ] Replace `fetchAllAssets()` with API call
- [ ] Remove `addAsset()` (assets created via transactions)
- [ ] Remove `deleteAsset()` (managed by backend)
- [ ] Remove price fetching logic (handled by backend)
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 3.4 Account Operations
- [ ] Replace `addAccount()` with API call
- [ ] Add `fetchAllAccounts()` method
- [ ] Add `updateAccount()` method
- [ ] Add `deleteAccount()` method
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 3.5 Net Worth Operations
- [ ] Replace `fetchAllNetworthSnapshots()` with API history endpoint
- [ ] Remove `addSnapshot()` (backend manages snapshots)
- [ ] Remove `rebuildHistoricalSnapshots()` logic
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 3.6 Remove Deprecated Code
- [ ] Remove `refreshAllPrices()` method
- [ ] Remove `fetchLatestPrice()` method
- [ ] Remove `assetPrices` dictionary cache
- [ ] Remove `isAssetPriceRefreshed` flag
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Phase 4: ViewModel Simplification

### 4.1 HomeViewModel Updates
- [ ] Replace `loadData()` with single dashboard API call
- [ ] Map `APIDashboardResponse` directly to `HomeViewState`
- [ ] Simplify `onSave(transaction:)` to POST + refresh
- [ ] Remove `calculateAssetTotals()` (backend provides totals)
- [ ] Remove `updateGroupHoldingsForAllCategories()` (backend provides grouped data)
- [ ] Remove `processGroupTransactions()` (no longer needed)
- [ ] Update `rebuildHistoricalSnapshots()` to use API history endpoint
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 4.2 HomeViewState Updates
- [ ] Review and simplify `HomeViewState` struct
- [ ] Update `GroupedAssetHolding` type to match API response format
- [ ] Add loading states for API calls
- [ ] Add error state for API failures
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 4.3 Filter Logic
- [ ] Update `selectFilter()` to work with API data structure
- [ ] Ensure `filteredAssets` populates correctly from API response
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 4.4 Error Handling in UI
- [ ] Add error banner/alert for API failures
- [ ] Implement pull-to-refresh for dashboard
- [ ] Add loading indicators during API calls
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Phase 5: Testing & Validation

### 5.1 Unit Tests
- [ ] Ensure all existing `HomeViewModelTests` pass
- [ ] Add tests for `APIService` with mocked responses
- [ ] Add tests for model mappers
- [ ] Add tests for error handling
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 5.2 Integration Testing
- [ ] Test authentication flow end-to-end
- [ ] Test transaction creation and dashboard refresh
- [ ] Test account management flow
- [ ] Test net worth history loading
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 5.3 Manual Testing
- [ ] Verify dashboard loads correctly
- [ ] Verify transaction add/edit/delete works
- [ ] Verify account management works
- [ ] Verify chart displays historical data
- [ ] Test error scenarios (no network, 401, 500)
- [ ] Test loading states and user feedback
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Phase 6: Cleanup & Documentation

### 6.1 Remove SwiftData Dependencies
- [ ] Remove SwiftData model files or mark as deprecated
- [ ] Remove `ModelContext` usage from ViewModels
- [ ] Remove `@Query` property wrappers from Views
- [ ] Update `VaultTrackerApp` container setup
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 6.2 Code Cleanup
- [ ] Remove unused imports
- [ ] Remove commented-out code
- [ ] Update code comments and documentation
- [ ] Run linter and fix warnings
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

### 6.3 Documentation Updates
- [ ] Update PROJECT_ROADMAP.md to mark Phase 3 complete
- [ ] Document API integration architecture
- [ ] Update README with new setup instructions
- [ ] Document environment configuration
- [ ] Update `API_Implementation_TechSpec.md`
- [ ] Commit changes with comments
- [ ] Update `TODO_APIImplementation.md`

---

## Notes

### API Base URLs
- **Development:** `http://localhost:8000`
- **Production:** TBD

### Key Files to Modify
- `VaultTracker/Managers/DataService.swift`
- `VaultTracker/Managers/NetworkService.swift`
- `VaultTracker/Home/HomeViewModel.swift`
- `VaultTracker/Home/HomeView.swift`
- `VaultTracker/Managers/AuthManager.swift`

### New Files to Create
- `VaultTracker/API/APIConfiguration.swift`
- `VaultTracker/API/APIService.swift`
- `VaultTracker/API/APIServiceProtocol.swift`
- `VaultTracker/API/Models/` (response models)
- `VaultTracker/API/Mappers/` (model mappers)
- `VaultTracker/API/Errors/APIError.swift`

### Dependencies
- Existing `NetworkService` can be reused with modifications
- Firebase Auth SDK for JWT token retrieval
- No new external dependencies required
