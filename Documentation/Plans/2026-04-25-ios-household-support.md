---

name: iOS household multi-account support
overview: Consume the household APIs (already built in VaultTrackerAPI) to enable iOS users to create/join households, view a combined household dashboard with per-member collapsible sections, and manage a shared FIRE profile. Mirrors the Web implementation patterns.
todos:

- id: ios-api-household-models
  content: "API Models + tests: add APIHouseholdResponse, APIHouseholdMember, APIHouseholdInviteCodeResponse, APIHouseholdDashboardResponse, and APIHouseholdMemberDashboard to API/Models/ using the backend field names"
  status: completed
- id: ios-api-household-endpoints
  content: "API Layer + tests: add household methods to APIServiceProtocol + APIService (create, get-mine with 404-to-nil, generate-code, join, leave, dashboard/household, networth/history/household, fire-profile GET/PUT)"
  status: completed
- id: ios-domain-models
  content: "Domain Models: add Household, HouseholdMember, HouseholdInviteCode, and FIRE profile domain types only if the UI should not use APIFIREProfileResponse directly"
  status: completed
- id: ios-mappers
  content: "Mappers + tests: add HouseholdMapper, HouseholdDashboardMapper.toViewState, and FIRE profile mapping if domain FIRE types are introduced"
  status: completed
- id: ios-dataservice-household
  content: "DataService + MockDataService + tests: add household methods to DataServiceProtocol + DataService (fetchHousehold, createHousehold, generateInviteCode, joinHousehold, leaveHousehold, fetchHouseholdDashboard, fetchHouseholdNetWorthHistory, getHouseholdFIRE, updateHouseholdFIRE)"
  status: completed
- id: ios-household-settings-vm
  content: "ViewModel + tests: create HouseholdSettingsViewModel for create/join/leave/invite flows with state management"
  status: completed
- id: ios-household-settings-ui
  content: "UI + UI page object: expand ProfileView with HouseholdSettingsSection (create, join via code input, leave with confirm, generate code with copy + expiry display) and stable accessibility identifiers"
  status: completed
- id: ios-homevm-household-mode
  content: "HomeViewModel + tests: add householdMode toggle, extend loadData for household dashboard, wire net worth history to household endpoint when in household mode"
  status: completed
- id: ios-homeview-household-ui
  content: "HomeView + UI tests: add Household/Just Me segmented toggle (visible when in household), render per-member collapsible MemberSection components"
  status: completed
- id: ios-fire-api-models
  content: "FIRE API + tests: add APIFIREProfileInput, APIFIREProfileResponse, APIFIREProjectionResponse and all nested types to API/Models/; add personal FIRE endpoints and household FIRE GET/PUT using the same input/response types"
  status: completed
- id: ios-fire-dataservice
  content: "FIRE DataService + MockDataService: add fetchFIREProfile, updateFIREProfile, fetchFIREProjection, fetchHouseholdFIRE, and updateHouseholdFIRE to DataServiceProtocol + DataService"
  status: completed
- id: ios-fire-screen
  content: "FIRE UI + tests: create FIREView + FIREViewModel (new tab or profile subsection), edit household shared inputs when in household, show personal projection only in personal mode"
  status: completed
- id: ios-tests-unit
  content: "Unit Test Sweep: fill any remaining gaps after slice tests for HouseholdMapper, HouseholdDashboardMapper, HouseholdSettingsViewModel, HomeViewModel household mode, FIREViewModel"
  status: completed
- id: ios-tests-ui
  content: "UI Test Sweep: add HouseholdSettingsPage page object if not already added and cover create/join/leave flows, dashboard household toggle, member section expansion"
  status: completed
- id: ios-docs-update
  content: "Docs: update VaultTrackerIOS/VaultTracker/CLAUDE.md and Documentation/VaultTracker System Design.md with household iOS changes"
  status: completed
isProject: false

---

## Context

The household (multi-account) feature allows two users to share a combined financial view. The API endpoints are complete (see `Documentation/Plans/2026-04-18-multi-account-support.md`). Web implementation is complete and provides the reference behavior. This plan covers the iOS client implementation to consume those APIs.

## Decisions (inherited from API plan)

- **Household membership:** One household per user, max 2 members in v1
- **Dashboard default:** Household view when in a household, with "Just Me" toggle
- **FIRE:** Single shared household FIRE profile using the same input/response shape as personal FIRE; personal profile hidden while in household
- **Write access:** View-only across members (each user edits only their own data)
- **Invite codes:** Short-lived (15min), single-use, 8-char codes

## API Endpoints to Consume

### Household Endpoints
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/households` | Create household |
| GET | `/api/v1/households/me` | Get current household |
| POST | `/api/v1/households/invite-codes` | Generate invite code |
| POST | `/api/v1/households/join` | Join via code |
| DELETE | `/api/v1/households/me/membership` | Leave household |
| GET | `/api/v1/dashboard/household` | Household dashboard |
| GET | `/api/v1/networth/history/household` | Household net worth history |
| GET | `/api/v1/households/me/fire-profile` | Get household FIRE |
| PUT | `/api/v1/households/me/fire-profile` | Update household FIRE |

### Personal FIRE Endpoints (not yet in iOS)
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/fire/profile` | Get personal FIRE profile |
| PUT | `/api/v1/fire/profile` | Update personal FIRE profile |
| GET | `/api/v1/fire/projection` | Get FIRE projection (targets, curve, assessment) |

## Implementation Details

### 1. API Models (`API/Models/APIHouseholdModels.swift`)

```swift
// Response from GET /households/me
struct APIHouseholdResponse: Codable {
    let id: String
    let members: [APIHouseholdMember]
    let createdAt: Date
}

struct APIHouseholdMember: Codable {
    let userId: String
    let email: String?
}

// Response from POST /households/invite-codes
struct APIHouseholdInviteCodeResponse: Codable {
    let code: String
    let expiresAt: Date
}

// Request for POST /households/join
struct APIHouseholdJoinRequest: Codable {
    let code: String
}

// Response from GET /dashboard/household
struct APIHouseholdDashboardResponse: Codable {
    let householdId: String
    let totalNetWorth: Double
    let categoryTotals: APICategoryTotals
    let members: [APIHouseholdMemberDashboard]
}

struct APIHouseholdMemberDashboard: Codable {
    let userId: String
    let email: String?
    let totalNetWorth: Double
    let categoryTotals: APICategoryTotals
    let groupedHoldings: [String: [APIGroupedHolding]]
}
```

**No separate household FIRE DTO:** Household FIRE `GET/PUT /households/me/fire-profile` uses the same API shapes as personal FIRE:
- `PUT` body: `APIFIREProfileInput`
- response: `APIFIREProfileResponse`

### 2. APIServiceProtocol Extensions

Add to `API/APIServiceProtocol.swift`:

```swift
// MARK: - Households

func fetchHousehold() async throws -> APIHouseholdResponse?
func createHousehold() async throws -> APIHouseholdResponse
func generateInviteCode() async throws -> APIHouseholdInviteCodeResponse
func joinHousehold(code: String) async throws -> APIHouseholdResponse
func leaveHousehold() async throws

// MARK: - Household Dashboard

func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse
func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws -> APINetWorthHistoryResponse

// MARK: - Household FIRE

func fetchHouseholdFIREProfile() async throws -> APIFIREProfileResponse
func updateHouseholdFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse

// MARK: - Personal FIRE (new)

func fetchFIREProfile() async throws -> APIFIREProfileResponse
func updateFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse
func fetchFIREProjection() async throws -> APIFIREProjectionResponse
```

**404 behavior:** `GET /households/me` returns `404 "Not a member of a household"` when the user is not in a household. iOS should translate that exact response to `nil` from `fetchHousehold()`; other 404s and all non-household API errors should still throw. Household-scoped dashboard, net worth history, and FIRE calls also return that 404 when the user is not a member and should surface as recoverable UI errors or be skipped when `fetchHousehold()` is nil.

### 3. Domain Models (`Models/Household.swift`)

```swift
struct Household {
    let id: String
    let members: [HouseholdMember]
    let createdAt: Date
}

struct HouseholdMember {
    let userId: String
    let email: String?
}

struct HouseholdInviteCode {
    let code: String
    let expiresAt: Date
}
```

### 4. Mappers (`API/Mappers/HouseholdMapper.swift`)

- `HouseholdMapper.toDomain(_ api: APIHouseholdResponse) -> Household`
- `HouseholdDashboardMapper.toViewState(_ api: APIHouseholdDashboardResponse) -> HouseholdHomeViewState`

### 5. DataServiceProtocol Extensions

Add to `Managers/DataServiceProtocol.swift`:

```swift
// MARK: - Households

func fetchHousehold() async throws -> Household?
func createHousehold() async throws -> Household
func generateInviteCode() async throws -> HouseholdInviteCode
func joinHousehold(code: String) async throws -> Household
func leaveHousehold() async throws

// MARK: - Household Dashboard

func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse
func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot]

// MARK: - Household FIRE

func fetchHouseholdFIREProfile() async throws -> APIFIREProfileResponse
func updateHouseholdFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse

// MARK: - Personal FIRE (new)

func fetchFIREProfile() async throws -> APIFIREProfileResponse
func updateFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse
func fetchFIREProjection() async throws -> APIFIREProjectionResponse
```

### 6. HouseholdSettingsViewModel (`Profile/HouseholdSettingsViewModel.swift`)

```swift
@MainActor
final class HouseholdSettingsViewModel: ObservableObject {
    @Published var household: Household?
    @Published var inviteCode: HouseholdInviteCode?
    @Published var joinCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadHousehold() async
    func createHousehold() async
    func generateInviteCode() async
    func joinHousehold() async
    func leaveHousehold() async
}
```

### 7. ProfileView Expansion (`Profile/ProfileView.swift`)

Add `HouseholdSettingsSection` below user info:

**Not in household:**
- "Create Household" button
- "Join Household" with code input field + join button

**In household:**
- Member list (email, or "Household member" fallback)
- "Generate Invite Code" button -> shows code + copy button + expiry countdown
- "Leave Household" button with confirmation dialog

### 8. HomeViewModel Household Mode (`Home/HomeViewModel.swift`)

```swift
// New state
@Published var isInHousehold: Bool = false
@Published var householdMode: Bool = true  // true = household view, false = just me
@Published var householdViewState: HouseholdHomeViewState?

// New struct
struct HouseholdHomeViewState {
    var totalNetWorth: Double
    var categoryTotals: APICategoryTotals
    var members: [MemberViewState]
}

struct MemberViewState {
    var userId: String
    var email: String?
    var totalNetWorth: Double
    var categoryTotals: APICategoryTotals
    var groupedHoldings: [String: GroupedAssetHolding]
}

// Modified loadData()
func loadData() async {
    // Check household membership
    household = try? await dataService.fetchHousehold()
    isInHousehold = household != nil

    if isInHousehold && householdMode {
        // Load household dashboard
        let response = try await dataService.fetchHouseholdDashboard()
        householdViewState = HouseholdDashboardMapper.toViewState(response)
        snapshots = try await dataService.fetchHouseholdNetWorthHistory(period: selectedPeriod)
    } else {
        // Existing personal dashboard logic
    }
}
```

### 9. HomeView Household UI (`Home/HomeView.swift`)

**Additions:**
- Segmented toggle `Household | Just Me` (visible only when `isInHousehold`)
- When in household mode:
  - Hero total shows `householdViewState.totalNetWorth`
  - Category bar shows household `categoryTotals`
  - Replace asset list with `MemberSectionView` for each member

**New component:** `Home/MemberSectionView.swift`
- Collapsible card per member
- Header: member email (or "Household member" fallback) + their total net worth
- Expanded: their category breakdown + holdings grid (reuse existing `expandedDetailView` pattern)

### 10. Personal FIRE API Models (`API/Models/APIFIREModels.swift`)

```swift
// Request for PUT /fire/profile
struct APIFIREProfileInput: Codable {
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let targetRetirementAge: Int?
}

// Response for GET /fire/profile
struct APIFIREProfileResponse: Codable {
    let id: String
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let targetRetirementAge: Int?
    let createdAt: Date
    let updatedAt: Date
}

// Response for GET /fire/projection
struct APIFIREProjectionResponse: Codable {
    let status: String  // "reachable", "beyond_horizon", "unreachable"
    let unreachableReason: String?
    let inputs: APIFIREProjectionInputs
    let allocation: APIFIREAllocation?
    let blendedReturn: Double?
    let realBlendedReturn: Double?
    let inflationRate: Double?
    let annualSavings: Double?
    let savingsRate: Double?
    let fireTargets: APIFIRETargets
    let projectionCurve: [APIFIREProjectionPoint]
    let monthlyBreakdown: APIFIREMonthlyBreakdown
    let goalAssessment: APIFIREGoalAssessment?
}

struct APIFIREProjectionInputs: Codable {
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let currentNetWorth: Double
    let targetRetirementAge: Int?
}

struct APIFIREAllocationSlice: Codable {
    let value: Double
    let percentage: Double
    let expectedReturn: Double
}

struct APIFIREAllocation: Codable {
    let crypto: APIFIREAllocationSlice
    let stocks: APIFIREAllocationSlice
    let cash: APIFIREAllocationSlice
    let realEstate: APIFIREAllocationSlice
    let retirement: APIFIREAllocationSlice
}

struct APIFIRETargetTier: Codable {
    let targetAmount: Double
    let yearsToTarget: Int?
    let targetAge: Int?
}

struct APIFIRETargets: Codable {
    let leanFire: APIFIRETargetTier
    let fire: APIFIRETargetTier
    let fatFire: APIFIRETargetTier
}

struct APIFIREProjectionPoint: Codable {
    let age: Int
    let year: Int
    let projectedValue: Double
}

struct APIFIREMonthlyBreakdown: Codable {
    let monthlySurplus: Double
    let monthsToFire: Int?
}

struct APIFIREGoalAssessment: Codable {
    let targetAge: Int
    let requiredSavingsRate: Double
    let currentSavingsRate: Double
    let status: String  // "ahead", "on_track", "behind"
    let gapAmount: Double
    let computedBeyondProjectionHorizon: Bool
}
```

### 11. FIRE Screen (`FIRE/FIREView.swift`, `FIRE/FIREViewModel.swift`)

**New tab or subsection in Profile:**
- If in household: fetch/display/edit shared `APIFIREProfileResponse`/domain FIRE profile with banner "Shared with your household"
- If not in household: fetch/display/edit personal `APIFIREProfileResponse`/domain FIRE profile

**FIREViewModel responsibilities:**
- Check household membership on load
- Fetch appropriate profile (household or personal)
- Fetch projection for chart and targets only in personal mode
- In household mode, edit shared FIRE inputs and show a clear "household projection is not available yet" empty/chart state
- Handle profile updates

## File Changes Summary

| Path | Change |
|------|--------|
| `API/Models/APIHouseholdModels.swift` | New file — household API types |
| `API/Models/APIFIREModels.swift` | New file — FIRE API types used by personal and household FIRE |
| `API/APIServiceProtocol.swift` | Add 12 methods (9 household + 3 FIRE) |
| `API/APIService.swift` | Implement 12 methods |
| `API/APIConfiguration.swift` | Add household + FIRE endpoint constants |
| `API/Mappers/HouseholdMapper.swift` | New file |
| `API/Mappers/HouseholdDashboardMapper.swift` | New file |
| `Models/Household.swift` | New file — domain types |
| `Managers/DataServiceProtocol.swift` | Add 12 methods |
| `Managers/DataService.swift` | Implement 12 methods |
| `VaultTrackerTests/MockDataService.swift` | Add stubs/storage for new DataServiceProtocol methods |
| `Profile/HouseholdSettingsViewModel.swift` | New file |
| `Profile/ProfileView.swift` | Add HouseholdSettingsSection |
| `Home/HomeViewModel.swift` | Add household mode, state, loading |
| `Home/HomeView.swift` | Add toggle, member sections |
| `Home/MemberSectionView.swift` | New file |
| `FIRE/FIREView.swift` | New file — FIRE calculator UI |
| `FIRE/FIREViewModel.swift` | New file — FIRE state management |
| `VaultTrackerUITests/PageObjects/HouseholdSettingsPage.swift` | New file — page object for household profile UI |

## Testing

### Unit Tests (`VaultTrackerTests/`)
- `HouseholdMapperTests.swift` — verify API to domain mapping
- `HouseholdDashboardMapperTests.swift` — verify dashboard response mapping
- `HouseholdSettingsViewModelTests.swift` — mock DataService, test create/join/leave flows
- `HomeViewModelHouseholdTests.swift` — test mode toggle, household loading

### UI Tests (`VaultTrackerUITests/`)
- `HouseholdSettingsPageTests.swift` — create, generate code (copy), join (error states), leave (confirm)
- `HouseholdDashboardTests.swift` — toggle visibility, member sections expand/collapse

### Manual Verification
1. Create household in iOS → verify in API/Web
2. Generate code in iOS → join from Web (or second iOS device)
3. Verify household dashboard shows both members
4. Toggle "Just Me" → verify shows only personal data
5. Leave household → verify cleanup and return to personal view

## Dependencies

- API household endpoints: complete per `2026-04-18-multi-account-support.md`
- API personal FIRE endpoints: complete (GET/PUT `/fire/profile`, GET `/fire/projection`)
- iOS does not currently have FIRE endpoints — this plan includes adding them

## Out of Scope

- Push notifications for household events
- Real-time sync when partner adds data
- Household chat/messaging
