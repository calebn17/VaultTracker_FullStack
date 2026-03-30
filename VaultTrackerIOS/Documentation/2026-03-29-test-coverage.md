# iOS Test Coverage Map

**Date:** 2026-03-29
**Total tests:** ~148 (99 unit · 20 integration · 30 UI)

---

## Test Suite Overview

| Layer | File(s) | Count | Requires backend? |
|-------|---------|-------|-------------------|
| Unit | `VaultTrackerTests/*.swift` | ~99 | No |
| Integration | `VaultTrackerTests/*IntegrationTests.swift` | 20 | Yes (`DEBUG_AUTH_ENABLED=true`) |
| UI | `VaultTrackerUITests/*.swift` | 30 | Yes (simulator + backend) |

---

## Sub-Module Coverage

### API Layer

#### `APIError`
**Features:** Maps HTTP status codes (401, 403, 404, 5xx) to typed error cases; parses FastAPI 422 validation messages; provides user-readable `errorDescription`.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `APIErrorTests.swift` | 13 | ✅ Complete |

#### `API Models (Codable)`
**Features:** `APISmartTransactionCreateRequest` (snake_case encoding), `APIAnalyticsResponse`, `APIPriceRefreshResult`, `APIEnrichedTransactionResponse` (nested asset + account), `APIAccountResponse`, `APIAssetResponse`, `APINetWorthHistoryResponse`.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `APIModelsCodableTests.swift` | 7 | ✅ Complete (all key models decoded/encoded) |

#### `APIService` / `AuthTokenProvider`
**Features:** All REST endpoints; JWT injection; 401 token refresh + retry; debug bypass.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `APIIntegrationTests.swift` | 6 | ✅ Auth flow, account CRUD, analytics, price refresh |
| Unit | 0 | ⚠️ No unit tests (URLSession mocking not set up; covered by integration) |

---

### Mappers

#### `AssetMapper`
**Features:** UUID parsing (valid + fallback), category mapping (all 5 categories, snake/camelCase), symbol-to-name fallback, price derivation from current_value/quantity.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AssetMapperTests.swift` | 11 | ✅ Complete |

#### `AccountMapper`
**Features:** UUID parsing, account type mapping (all variants + camelCase), array mapping.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AccountMapperTests.swift` | 9 | ✅ Complete |

#### `TransactionMapper`
**Features:** Buy/sell type mapping, nested asset + account, symbol-to-name fallback, all categories (crypto, stocks, cash, realEstate, retirement), array order preservation.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `TransactionMapperTests.swift` | 7 | ✅ Complete (sell, realEstate, retirement, symbol fallback added 2026-03-29) |

#### `DashboardMapper`
**Features:** Net worth + category totals, grouped holdings per category (all 5), both snake_case and camelCase keys, unknown category ignored, filter state initialization.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `DashboardMapperTests.swift` | 15 | ✅ Complete |

---

### ViewModels

#### `HomeViewModel`
**Features:** `loadData()` (dashboard fetch, error handling, filter preservation), `onSave()` (smart transaction → reload), `refreshPrices()` (with error), `selectFilter()`, `selectNetWorthPeriod()`.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `HomeViewModelTests.swift` | 18 | ✅ Comprehensive unit |
| `HomeViewModelIntegrationTests.swift` | 7 | ✅ Real API: empty state, create asset, filter, clear data |

#### `AnalyticsViewModel`
**Features:** `load()` fetches analytics; sorts allocation entries alphabetically; populates performance block; handles API + generic errors; clears errorMessage on success; retains previous data on error.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AnalyticsViewModelTests.swift` | 9 | ✅ Complete (added 2026-03-29) |

#### `AddAssetFormViewModel`
**Features:** Form state defaults (buy, cash category); validation (`isFormValid`, `isAccountTypeValidForAssetCategory`); cash encoding (quantity = dollar amount, pricePerUnit = 1.0); crypto/stocks encoding (quantity, symbol, pricePerUnit); sell transaction type; `save()` returns nil on invalid input.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AddAssetFormViewModelTests.swift` | 10 | ✅ Unit: validation + encoding (added 2026-03-29) |
| `AddAssetFormViewModelIntegrationTests.swift` | 7 | ✅ Real API: account creation/reuse, cash/stocks/real estate encoding |

#### `AuthManager`
**Features:** Firebase auth state machine (authenticating → authenticated → unauthenticated); auto sign-out on persistent 401.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| — | 0 | ❌ Not tested (Firebase lifecycle mocking deferred) |

---

### Views & UI

#### Login Flow
**Features:** Google Sign-In button, Apple Sign-In button, Debug Login (DEBUG builds only); redirects to Home on success.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `LoginUITests.swift` | 2 | ✅ Unauthenticated state, debug login → Home tab |

#### Home Tab
**Features:** Net worth display, category breakdown bar, period picker (daily/weekly/monthly), filter chips (All + 5 categories), Add Transaction button → modal, Refresh Prices button, category section expand/collapse, pull-to-refresh.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `HomeTabUITests.swift` | 8 | ✅ Net worth elements, period picker, filter chips, modal open, section toggle |

#### Add Asset Modal
**Features:** Category-dependent field visibility (symbol/quantity hidden for cash/realEstate), Save button disabled until valid, form submission closes modal, transaction type picker.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AddAssetModalUITests.swift` | 6 | ✅ Field visibility, Save button state, cash vs. crypto, form submit |

#### Analytics Tab
**Features:** Allocation section (one row per category, sorted), Performance section (gain/loss, cost basis, current value), pull-to-refresh.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `AnalyticsTabUITests.swift` | 3 | ⚠️ Section visibility only; data values not UI-verified |

#### Profile Tab
**Features:** Sign-out button → Login screen.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| `ProfileTabUITests.swift` | 2 | ✅ Sign-out flow |

#### `NetWorthChartView`
**Features:** Line chart from `[NetWorthSnapshot]`; period selection drives chart data.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| — | 0 | ⚠️ Visual only; no snapshot tooling in project |

#### Design System (`VTColors`, `VTTypography`, `VTComponents`)
**Features:** Color tokens, typography tokens, reusable button/chip/surface styles.

| Test file | Cases | Coverage |
|-----------|-------|----------|
| — | 0 | N/A — design tokens verified visually |

---

## Coverage Summary

| Sub-module | Unit | Integration | UI | Status |
|-----------|------|------------|-----|--------|
| `APIError` | ✅ 13 | — | — | Complete |
| `API Models (Codable)` | ✅ 7 | — | — | Complete |
| `APIService` | — | ✅ 6 | — | Good (integration only) |
| `AssetMapper` | ✅ 11 | — | — | Complete |
| `AccountMapper` | ✅ 9 | — | — | Complete |
| `TransactionMapper` | ✅ 7 | — | — | Complete |
| `DashboardMapper` | ✅ 15 | — | — | Complete |
| `HomeViewModel` | ✅ 18 | ✅ 7 | ✅ 8 | Comprehensive |
| `AnalyticsViewModel` | ✅ 9 | — | ⚠️ 3 (basic) | Good |
| `AddAssetFormViewModel` | ✅ 10 | ✅ 7 | ✅ 6 | Comprehensive |
| `AuthManager` | ❌ 0 | — | — | Not tested |
| Login UI | — | — | ✅ 2 | Basic |
| Analytics UI (data) | — | — | ⚠️ 3 | Basic |
| Profile UI | — | — | ✅ 2 | Adequate |
| `NetWorthChartView` | ❌ 0 | — | — | Visual only |
| Design System | — | — | — | N/A |

---

## CI Split

```
┌─────────────────────────────────────────────────────┐
│  Job: unit-tests (no backend)                       │
│  xcodebuild test -testPlan UnitTests                │
│  Target: VaultTrackerTests (excludes .integration)  │
│  Count: ~99 tests · always green in CI              │
├─────────────────────────────────────────────────────┤
│  Job: integration-tests (backend sidecar required)  │
│  Filter: .tags(.integration)                        │
│  Count: 20 tests · gate on PR merge or nightly      │
├─────────────────────────────────────────────────────┤
│  Job: ui-tests (simulator + backend)                │
│  Target: VaultTrackerUITests                        │
│  Count: 30 tests · run on device farm / nightly     │
└─────────────────────────────────────────────────────┘
```
