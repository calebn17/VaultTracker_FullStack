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
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 1.4 Authentication Integration
- [x] Create `AuthTokenProvider.swift` to retrieve Firebase JWT token
- [x] Modify `NetworkService` to accept dynamic authorization headers
- [x] Implement token refresh on 401 responses
- [x] Add auto-logout on persistent authentication failures
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 1.5 Error Handling
- [x] Create `APIError.swift` with specific error cases
- [x] Implement error mapping from HTTP status codes
- [x] Add user-friendly error message generation
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

---

## Phase 2: Model Mapping Layer

### 2.1 Domain Model Updates
- [x] Review existing `Asset` model for API compatibility
- [x] Review existing `Account` model for API compatibility
- [x] Review existing `Transaction` model for API compatibility
- [x] Add `id` property mapping to existing models (UUID handling)
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 2.2 Mappers
- [x] Create `DashboardMapper.swift` to convert API response to `HomeViewState`
- [x] Create `AccountMapper.swift` for Account conversions
- [x] Create `AssetMapper.swift` for Asset conversions
- [x] Create `TransactionMapper.swift` for Transaction conversions
- [x] Handle date format conversions (ISO8601)
- [x] Handle category/type enum mappings
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

---

## Phase 3: DataService Refactoring

### 3.1 Dependency Injection
- [x] Add `APIService` as dependency in `DataService`
- [x] Create `DataServiceProtocol` if not exists
- [x] Update `DataService` initializer
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 3.2 Transaction Operations
- [x] Replace `addTransaction()` with API call + local update
- [x] Replace `fetchAllTransactions()` with API call
- [x] Replace `deleteTransaction()` with API call
- [x] Remove `deleteAllTransactions()` or convert to API batch operation
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 3.3 Asset Operations
- [x] Replace `fetchAllAssets()` with API call
- [x] Remove `addAsset()` (assets created via transactions)
- [x] Remove `deleteAsset()` (managed by backend)
- [x] Remove price fetching logic (handled by backend)
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 3.4 Account Operations
- [x] Replace `addAccount()` with API call
- [x] Add `fetchAllAccounts()` method
- [x] Add `updateAccount()` method
- [x] Add `deleteAccount()` method
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 3.5 Net Worth Operations
- [x] Replace `fetchAllNetworthSnapshots()` with API history endpoint
- [x] Remove `addSnapshot()` (backend manages snapshots)
- [x] Remove `rebuildHistoricalSnapshots()` logic
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 3.6 Remove Deprecated Code
- [x] Remove `refreshAllPrices()` method
- [x] Remove `fetchLatestPrice()` method
- [x] Remove `assetPrices` dictionary cache
- [x] Remove `isAssetPriceRefreshed` flag
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

---

## Phase 4: ViewModel Simplification

### 4.1 HomeViewModel Updates
- [x] Replace `loadData()` with single dashboard API call
- [x] Map `APIDashboardResponse` directly to `HomeViewState`
- [x] Simplify `onSave(transaction:)` to POST + refresh
- [x] Remove `calculateAssetTotals()` (backend provides totals)
- [x] Remove `updateGroupHoldingsForAllCategories()` (backend provides grouped data)
- [x] Remove `processGroupTransactions()` (no longer needed)
- [x] Update `rebuildHistoricalSnapshots()` to use API history endpoint
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 4.2 HomeViewState Updates
- [x] Review and simplify `HomeViewState` struct
- [x] Update `GroupedAssetHolding` type to match API response format
- [x] Add loading states for API calls
- [x] Add error state for API failures
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 4.3 Filter Logic
- [x] Update `selectFilter()` to work with API data structure
- [x] Ensure `filteredAssets` populates correctly from API response
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 4.4 Error Handling in UI
- [x] Add error banner/alert for API failures
- [x] Implement pull-to-refresh for dashboard
- [x] Add loading indicators during API calls
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

---

## Phase 5: Testing & Validation

### 5.1 Unit Tests
- [x] Ensure all existing `HomeViewModelTests` pass
- [x] Add tests for `APIService` with mocked responses
- [x] Add tests for model mappers
- [x] Add tests for error handling
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 5.2 Integration Testing
- [x] Test authentication flow end-to-end
- [x] Test transaction creation and dashboard refresh
- [x] Test account management flow
- [x] Test net worth history loading
- [x] Test HomeViewModel state management against live backend
- [x] Test AddAssetFormViewModel save flow against live backend
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

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
- [x] Remove SwiftData model files or mark as deprecated
- [x] Remove `ModelContext` usage from ViewModels
- [x] Remove `@Query` property wrappers from Views
- [x] Update `VaultTrackerApp` container setup
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 6.2 Code Cleanup
- [x] Remove unused imports
- [x] Remove commented-out code
- [x] Update code comments and documentation
- [x] Run linter and fix warnings
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

### 6.3 Documentation Updates
- [x] Update PROJECT_ROADMAP.md to mark Phase 3 complete
- [x] Document API integration architecture
- [x] Update README with new setup instructions
- [x] Document environment configuration
- [x] Update `API_Implementation_TechSpec.md`
- [x] Commit changes with comments
- [x] Update `TODO_APIImplementation.md`

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
