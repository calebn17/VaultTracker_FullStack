# iOS Test Plan — VaultTracker

**Date:** 2026-03-29
**Current state:** 123 tests (73 unit · 20 integration · 30 UI)
**Target after this plan:** ~144 tests

---

## 1. Architecture Overview

```
Views  →  ViewModels  →  DataServiceProtocol
                               ↓
                          DataService (concrete)
                               ↓
                          APIServiceProtocol
                               ↓
                           APIService (URLSession)
```

Each seam above is a testable boundary. ViewModels are injected with `DataServiceProtocol`, making `MockDataService` the primary test double for all unit tests.

---

## 2. Full Functionality Inventory

| Area | Components |
|------|-----------|
| **API Layer** | `APIService`, `APIServiceProtocol`, `AuthTokenProvider`, `APIError`, `APIConfiguration` |
| **API Models** | `APIDashboardResponse`, `APIAnalyticsResponse`, `APIAccountModels`, `APIAssetModels`, `APITransactionModels`, `APIPriceModels`, `APINetWorthHistoryResponse` |
| **Mappers** | `DashboardMapper`, `AssetMapper`, `AccountMapper`, `TransactionMapper` |
| **Data Service** | `DataService`, `DataServiceProtocol` |
| **ViewModels** | `HomeViewModel`, `AnalyticsViewModel`, `AddAssetFormViewModel`, `AuthManager` |
| **Views** | `HomeView`, `AnalyticsView`, `AddAssetModalView`, `ProfileView`, `LoginView`, `NetWorthChartView` |
| **Design System** | `VTColors`, `VTTypography`, `VTComponents` |

---

## 3. Layer-by-Layer Coverage Audit

### Unit Tests (73 tests)

| Component | Tests | Status |
|-----------|-------|--------|
| `APIError` | 13 | ✅ Complete |
| `APIModels Codable` | 4 | ⚠️ Partial (5 models not covered) |
| `AssetMapper` | 11 | ✅ Complete |
| `AccountMapper` | 9 | ✅ Complete |
| `TransactionMapper` | 3 | ⚠️ Partial (sell type, realEstate, retirement missing) |
| `DashboardMapper` | 15 | ✅ Complete |
| `HomeViewModel` | 18 | ✅ Comprehensive |
| `AnalyticsViewModel` | 0 | ❌ Not tested |
| `AddAssetFormViewModel` | 0 | ❌ Not tested (unit level) |
| `AuthManager` | 0 | ❌ Not tested |
| `NetWorthChartView` | 0 | N/A (visual rendering) |
| `VTColors/VTTypography` | 0 | N/A (design tokens) |

### Integration Tests (20 tests)

| Component | Tests | Status |
|-----------|-------|--------|
| `HomeViewModel` (real API) | 7 | ✅ Good |
| `AddAssetFormViewModel` (real API) | 7 | ✅ Good |
| `APIService` (real API) | 6 | ✅ Good |

### UI Tests (30 tests)

| Screen | Tests | Status |
|--------|-------|--------|
| Login | 2 | ✅ Basic |
| Home tab | 8 | ✅ Solid |
| Add Asset Modal | 6 | ✅ Good |
| Analytics tab | 3 | ⚠️ Basic (section visibility only) |
| Profile tab | 2 | ✅ Adequate |

---

## 4. Gap Analysis (Priority Order)

### P1 — Missing unit test coverage (blocking CI confidence)

1. **`AnalyticsViewModel`** — zero unit tests. Identical structure to `HomeViewModel`. `MockDataService` already has `analyticsStub`; just needs `fetchAnalyticsCallCount` and `analyticsError` wired.
2. **`AddAssetFormViewModel` validation** — integration tests prove the happy path end-to-end, but unit tests are needed for validation edge cases (invalid price, empty name, account/category mismatch) that would be slow/flaky to test against a live API.

### P2 — Thin coverage that could miss regressions

3. **`TransactionMapper`** — 3 tests only cover buy+stocks, sell+cash, and array ordering. Missing: `realEstate`, `retirement`, explicit sell type assertion.
4. **`APIModels Codable`** — `APIAccountResponse`, `APIAssetResponse`, `APINetWorthHistoryResponse` have no decode tests.

### P3 — Explicitly deferred (not done in this plan, documented reason)

- **`AuthManager`** — deferred in *this* plan because production code calls `Auth.auth()` and
  `NotificationCenter.default` directly (see [`AuthManager.swift`](../../VaultTracker/Managers/AuthManager.swift)),
  so Swift Testing cannot drive auth state or notifications in isolation. **Follow-up decision
  (per current Firebase Auth docs, Context7 `/firebase/firebase-ios-sdk` + `/websites/firebase_google`):**
  do **not** rely on a third-party SPM “FirebaseAuthMock” package. Use **protocol-based injection**
  (app target) and **fakes in `VaultTrackerTests`**—the same pattern as `DataServiceProtocol` /
  `MockDataService`. Concrete steps and test scope are in **§9**.
- **Analytics UI data values** — UI tests asserting specific dollar figures become brittle when
  backend seed data changes. The right fix is a sealed test environment with fixed seed data, which
  is a larger infrastructure change. Deferred until CI has a reproducible data fixture.

> **These are gaps, not permanent exclusions.** Each should become P1 in the next testing plan.

---

## 5. Test Pyramid Target

```
          ┌──────────────────────────┐
          │     UI Tests (30)   10%  │
          ├──────────────────────────┤
          │  Integration (20)   15%  │
          ├──────────────────────────┤
          │    Unit Tests (94)  65%  │  ← bulk of coverage
          └──────────────────────────┘
```

Unit tests are fast, isolated, and cheapest to maintain. The dependency-injection architecture (all ViewModels inject `DataServiceProtocol`) was designed for this.

**What NOT to test:**
- `VTColors`, `VTTypography`, `VTComponents` — visual design tokens; verified by eye
- `NetWorthChartView` rendering — requires snapshot tooling not yet in the project
- `AuthManager` — deferred until DI + fakes land; see **§9**
- `NetworkService` (legacy) — not used in new features

---

## 6. New Tests

### 6.1 `MockDataService.swift` — additions

Add `fetchAnalyticsCallCount` counter and `analyticsError` stub, mirroring the existing `refreshPrices` pattern:

```swift
private(set) var fetchAnalyticsCallCount = 0
var analyticsError: Error?

func fetchAnalytics() async throws -> APIAnalyticsResponse {
    fetchAnalyticsCallCount += 1
    if let error = analyticsError { throw error }
    return analyticsStub
}
```

### 6.2 `AnalyticsViewModelTests.swift` (NEW — 9 tests)

`@Suite("AnalyticsViewModel", .serialized)` · `@MainActor` · `MockDataService` + `AnalyticsViewModel`

| Test | What it proves |
|------|---------------|
| `loadSetsAllocationEntriesSortedAlphabetically` | `allocation: ["stocks":30k, "crypto":60k, "cash":10k]` → sorted `["cash","crypto","stocks"]` with correct values |
| `loadSetsPerformanceBlock` | `performance(totalGainLoss:12345, costBasis:87655)` → `viewModel.performance?.totalGainLoss == 12345` |
| `loadClearsLoadingStateOnSuccess` | `isLoading == false` after `load()` completes |
| `loadClearsErrorMessageOnSuccess` | Pre-set `errorMessage = "stale error"` → nil after successful load |
| `loadCallsFetchAnalyticsExactlyOnce` | `fetchAnalyticsCallCount == 1`; second call → `== 2` |
| `loadSetsErrorMessageOnAPIError` | Stub throws `APIError.serverError(500)` → `errorMessage == "Server error (500)"`, `isLoading == false` |
| `loadSetsErrorMessageOnGenericError` | Stub throws `URLError(.notConnectedToInternet)` → `errorMessage != nil`, `isLoading == false` |
| `loadWithEmptyAllocationProducesEmptyEntries` | `allocation: [:]` → `allocationEntries.isEmpty == true` |
| `loadRetainsPreviousDataOnError` | Successful load → error load → `allocationEntries` retains previous values (not cleared on error) |

### 6.3 `AddAssetFormViewModelTests.swift` (NEW — 9 tests)

`@Suite("AddAssetFormViewModel — Unit", .serialized)` · `@MainActor` · `MockDataService` + `AddAssetFormViewModel`

These cover validation logic not covered by the integration tests.

| Test | What it proves |
|------|---------------|
| `saveReturnsNilWhenAssetNameIsEmpty` | `name = ""`, valid other fields → `save()` returns nil |
| `saveReturnsNilWhenAccountNameIsEmpty` | `accountName = ""` → `save()` returns nil |
| `saveReturnsNilWhenPriceIsNegative` | `pricePerUnit = "-50"` → `save()` returns nil (negative price fails `isValidNonNegativeNumber`) |
| `saveReturnsNilWhenPriceIsNotANumber` | `pricePerUnit = "abc"` → `save()` returns nil |
| `saveReturnsNilWhenAccountTypeMismatchesCategory` | `selectedCategory = .crypto`, `accountType = .bank` → fails `isAccountTypeValidForAssetCategory` → returns nil |
| `saveReturnsCashRequestWithCorrectEncoding` | `selectedCategory = .cash`, `name = "Savings"`, `pricePerUnit = "5000"`, `accountType = .bank` → `request.quantity == 5000.0`, `request.pricePerUnit == 1.0`, `request.symbol == nil`, `request.category == "cash"` |
| `saveReturnsCryptoRequestWithCorrectEncoding` | `selectedCategory = .crypto`, `name = "Bitcoin"`, `symbol = "BTC"`, `quantity = "0.5"`, `pricePerUnit = "60000"`, `accountType = .cryptoExchange` → `request.quantity == 0.5`, `request.pricePerUnit == 60000`, `request.symbol == "BTC"` |
| `transactionTypeDefaultsToBuy` | Fresh VM → `transactionType == .buy` |
| `categoryDefaultsToCash` | Fresh VM → `selectedCategory == .cash` |

### 6.4 `TransactionMapperTests.swift` — 4 new test cases

| Test | What it proves |
|------|---------------|
| `mapsRealEstateTransaction` | `category: "realEstate"` → `Transaction.category == .realEstate` |
| `mapsRetirementTransaction` | `category: "retirement"` → `Transaction.category == .retirement` |
| `mapsSellTransactionType` | `transactionType: "sell"` → `Transaction.transactionType == .sell` (not `.buy` default) |
| `mapsTransactionWithNoSymbolFallsBackToName` | `symbol: nil, name: "My Property"` → `tx.symbol == "My Property"` |

### 6.5 `APIModelsCodableTests.swift` — 3 new test cases

| Test | What it proves |
|------|---------------|
| `accountResponseDecodesSnakeCaseKeys` | JSON with `account_type`, `user_id`, `created_at` → `APIAccountResponse.accountType == "bank"`, `name == "Chase"` |
| `assetResponseDecodesFromJSON` | JSON with `current_value`, `price_per_unit` → `APIAssetResponse.currentValue == 50000` |
| `netWorthHistoryResponseDecodesFromJSON` | JSON with `snapshots` array → `APINetWorthHistoryResponse.snapshots.count == 2`, `snapshots[0].value == 50000` |

---

## 7. CI Considerations

- **Unit tests** (`.serialized`, no `.tags(.integration)`) run without any backend. These are the primary CI gate.
- **Integration tests** are tagged `.tags(.integration)`. CI should run them with a backend sidecar (`DEBUG_AUTH_ENABLED=true`). They can be gated to a slower CI job or run on-demand.
- **UI tests** require a real simulator + backend. Run separately from unit tests.
- The `VaultTracker.xctestplan` currently excludes UI tests. Keep that separation.

---

## 8. Test Quality Principle

Every test in this project must be capable of failing. Concretely:
- Stubs use non-default, non-zero values so a missing assignment is detectable
- Assertions check specific values, not just non-nil or non-empty
- Error-path tests verify both `errorMessage` content AND `isLoading == false`
- Each test covers exactly one behavior; the test name is `verb + expectedOutcome`

---

## 9. Follow-up: `AuthManager` unit tests (architecture decision)

### 9.1 Why not a standalone “Firebase mock” library?

Firebase’s Apple-platform Auth API is documented around `Auth.auth()`, state observation, and
credential-based sign-in—not around a pluggable test double product. Current references:

- [Get started with Firebase Authentication on Apple platforms](https://firebase.google.com/docs/auth/ios/start)
- [Google Sign-In on Apple platforms](https://firebase.google.com/docs/auth/ios/google-signin)
- [Sign in with Apple](https://firebase.google.com/docs/auth/ios/apple)

The iOS SDK documents **`addStateDidChangeListener`** / **`removeStateDidChangeListener`**, checking
**`currentUser`**, and **`signOut()`** (local sign-out). A mock that can **invoke the same listener
callback shape** `(Auth, User?)` is enough for `AuthManager`’s state machine—implement that as a
**test-only type** behind a small protocol, not as an extra SPM dependency.

### 9.2 Refactor seams (minimal, mirrors existing DI style)

| Seam | Production | Tests |
|------|------------|--------|
| Auth backend | Thin adapter calling `Auth.auth()` (listener, `signOut()`, `signIn` with credential as needed) | Fake that stores the listener and exposes `simulateUser(_:)` / `simulateSignOut()` |
| Notifications | `NotificationCenter.default` | Fresh `NotificationCenter()` per test |
| Google / Apple UI flows | Unchanged | Still **UI tests** (or defer) — `GIDSignIn` / `ASAuthorizationController` are not worth faking in unit tests |

Also **retain listener handles and notification observer tokens** and remove them in `deinit` (today’s
`AuthManager` registers both without teardown—fix alongside injection for hygiene and stable tests).

### 9.3 Unit-test scope (first slice)

| Behavior | Assertion sketch |
|----------|------------------|
| Initial / listener fires `user == nil` | `authenticationState == .unauthenticated` |
| Listener fires non-nil user | `.authenticated` |
| `signOut()` when `AuthTokenProvider.isDebugSession` (DEBUG) | Clears debug flag, `.unauthenticated`, **no** Firebase `signOut` on fake |
| `signInDebug()` (DEBUG) | `isDebugSession == true`, `.authenticated` |
| Post `.authenticationRequired` on injected center | Fake `signOut` invoked (or state becomes unauthenticated per implementation) |

**Out of scope for v1 unit tests:** full `signInWithGoogle` / `signInWithApple` (keep UI / manual
coverage until Apple path is implemented).

### 9.4 Optional later: async auth state stream

The Firebase iOS SDK is moving toward an **`authStateChanges`** async sequence for state observation
([async stream design notes](https://github.com/firebase/firebase-ios-sdk/blob/main/docs/AsyncStreams/swift-async-sequence-api-design.md)).
Migrating `AuthManager` to that API is **optional** and only after confirming the SDK version pinned
by the project exposes it; it does not block the protocol + fake approach above.
