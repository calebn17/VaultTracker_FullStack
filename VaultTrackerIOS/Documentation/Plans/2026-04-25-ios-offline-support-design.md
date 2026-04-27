# iOS Offline Support Design

**Date:** 2026-04-25  
**Status:** Design aligned (matches [`.cursor/plans/ios_offline_support_2026-04-25.plan.md`](../../../.cursor/plans/ios_offline_support_2026-04-25.plan.md))  
**Target:** VaultTrackerIOS

## Context

VaultTracker iOS currently requires an active network connection for all operations. Users cannot record transactions when offline (e.g., traveling, poor connectivity), leading to forgotten entries or delayed tracking. This design introduces offline support that queues write operations locally and syncs automatically when connectivity is restored.

## Locked decisions (summary)

| Topic | Decision |
| ----- | -------- |
| Online layer | `DataService` and `APIService` stay **unchanged**; new types coordinate above them. |
| Dashboard reads | **Dual SwiftData cache:** personal `APIDashboardResponse` and household `APIHouseholdDashboardResponse`, chosen with the same rules as `HomeViewModel.loadData()` (`isInHousehold && householdMode`). |
| Transaction read cache | Rows keyed by **`userId` + API transaction id (`String`)**; matches `APIEnrichedTransactionResponse.id`. |
| Net worth history (v1) | **Cache** `APINetWorthHistoryResponse` (encoded `Data`) per **`userId` + `APINetWorthPeriod` + scope** (`personal` vs `household`), matching `fetchNetWorthHistory` / `fetchHouseholdNetWorthHistory`. Offline chart uses last cached series for the selected period with **`isStale`** when served from SwiftData. |
| Other tabs | **Global offline banner** on the authenticated shell; Analytics / FIRE / Profile unchanged unless a later plan adds cache. |
| Reachability tests | **`NetworkMonitoring`** protocol + production `NWPathMonitor` wrapper; unit tests use a **fake**, not a mocked `NWPathMonitor`. |
| Sync | **FIFO** queue, **single-flight** sync, **classified retries** (see [Sync contract](#sync-contract)). |
| Cache writes | **`DataRepository`** persists to `CachedDataStore` after **successful** online fetches it owns (dashboards, transactions, **net worth history** per period + scope). |
| Root UI | **`VaultTrackerApp`** `mainView` — wrap `OfflineBanner` + existing `TabView` (no `MainTabView`). |

## Requirements

| Requirement | Decision |
|-------------|----------|
| **Scope** | Smart transactions only (accounts auto-created by backend) |
| **Sync strategy** | Automatic sync when reachability reports online; manual **Sync now** on failures |
| **Error handling** | Classified retries (see [Sync contract](#sync-contract)); then user-visible failed state, discard, manual retry |
| **Storage** | SwiftData (secondary store; API remains source of truth when online) |
| **UI feedback** | Banner: offline, pending sync, failed count + retry |
| **Read caching** | Last-known **personal** and **household** dashboards, **net worth history per period** (personal + household), transaction list — each with `lastUpdated` / stale flag |
| **Excluded** | Household **creation** (per product requirement) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           SwiftUI Views                              │
│    (HomeView, AddAssetModal, transactions UI, other tabs)            │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          ViewModels                                  │
│    HomeViewModel observes: syncStatus, reachability, pendingCount    │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────────────┐
│      DataRepository      │     │        OfflineSyncManager           │
│  (new - coordinates     │◄───►│  (new - FIFO queue, classified      │
│   online/offline paths; │     │   retry, single-flight; publishes  │
│   writes read cache)    │     │   syncStatus, pendingCount)         │
└───────────┬─────────────┘     └──────────────┬──────────────────────┘
            │                                  │
            ▼                                  ▼
┌─────────────────────────┐     ┌─────────────────────────────────────┐
│      DataService        │     │       PendingTransactionStore     │
│   (existing - unchanged)│     │  (new - SwiftData, queued writes) │
└───────────┬─────────────┘     └─────────────────────────────────────┘
            │
            ▼                   ┌─────────────────────────────────────┐
┌─────────────────────────┐     │         CachedDataStore             │
│       APIService        │     │  (new - SwiftData, read cache)      │
│   (existing - unchanged)│     └─────────────────────────────────────┘
└─────────────────────────┘
                                ┌─────────────────────────────────────┐
                                │   NetworkMonitoring (protocol)     │
                                │   + NWPathMonitor implementation     │
                                └─────────────────────────────────────┘
```

**Key principle:** Existing `DataService` and `APIService` remain unchanged. New components wrap/coordinate without modifying the working network layer.

## Sync contract

1. **Ordering:** Pending smart transactions are processed **FIFO** (by `createdAt` or stable insert order).
2. **Single-flight:** At most **one** active sync pass (auto or manual) so the same item is not double-`POST`ed; `syncNow()` waits or no-ops if a sync is in progress (implementation chooses `await` vs debounce—document in code).
3. **Auth:** Sync uses the existing authenticated stack (`APIService` / Firebase token). If auth fails, surface **failed** state; **do not** silently drop queued payloads.
4. **Retries:** Classify outcomes:
   - **Transport / unreachable / timeouts / 5xx:** bounded retries with backoff (e.g. up to 3 attempts with exponential delay) before marking failed.
   - **4xx validation (400) / auth (401):** do **not** burn the full transport retry budget; surface failure quickly (optionally user-fixable) so bad payloads are not retried identically forever.
5. **Backoff (transport class):** e.g. immediate → 2s → 4s before terminal `.failed` for that enqueue cycle; tune in implementation.
6. **User actions:** Manual **Sync now**, per-item **Discard** (local queue id), and banner messaging for offline + failed counts.

## Components

### 1. SwiftData models

**Location:** `Managers/Offline/Models/`

**Schema / migrations:** `@Model` types store encoded `Data` for API DTOs. When API Codable shapes change, plan for **SwiftData schema migration** or versioned payload handling so old rows fail gracefully.

#### PendingTransaction.swift

```swift
@Model
final class PendingTransaction {
    @Attribute(.unique) var id: UUID
    var request: Data  // Encoded APISmartTransactionCreateRequest
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    var status: PendingStatus  // .pending, .syncing, .failed
}

enum PendingStatus: String, Codable {
    case pending    // Waiting to sync
    case syncing    // Currently being sent
    case failed     // Terminal failure for this cycle (user discard / manual retry resets policy TBD in code)
}
```

#### CachedPersonalDashboard.swift

```swift
@Model
final class CachedPersonalDashboard {
    @Attribute(.unique) var userId: String
    var data: Data  // Encoded APIDashboardResponse
    var lastUpdated: Date
}
```

#### CachedHouseholdDashboard.swift

```swift
@Model
final class CachedHouseholdDashboard {
    @Attribute(.unique) var userId: String
    var data: Data  // Encoded APIHouseholdDashboardResponse
    var lastUpdated: Date
}
```

*Rationale:* `HomeViewModel` switches between `fetchDashboard()` and `fetchHouseholdDashboard()`; offline read-through must mirror that split.

#### CachedNetWorthHistory.swift

Persists the API payload used to build `NetWorthSnapshot` arrays today ([`APINetWorthHistoryResponse`](../../VaultTracker/API/Models/APINetWorthHistoryResponse.swift)). One row per **user**, **period** (`daily` / `weekly` / `monthly`), and **scope** (personal vs household), so changing `selectedPeriod` or household mode can still hit cache offline.

```swift
@Model
final class CachedNetWorthHistory {
    /// e.g. "\(userId)|personal|daily" or "\(userId)|household|weekly"
    @Attribute(.unique) var cacheKey: String
    var userId: String
    /// "personal" or "household"
    var scope: String
    /// APINetWorthPeriod.rawValue
    var periodRaw: String
    var data: Data  // Encoded APINetWorthHistoryResponse
    var lastUpdated: Date
}
```

Map cached `Data` → `[NetWorthSnapshot]` using the same decoding + mapping as today’s stack (decode `APINetWorthHistoryResponse`, then map to domain like [`DataService.fetchNetWorthHistory`](../../VaultTracker/Managers/DataService.swift) / `fetchHouseholdNetWorthHistory`).

**Implementation note:** `DataService`’s public history methods return **`[NetWorthSnapshot]`** only, so they cannot supply the raw `Data` blob for SwiftData. The repository should obtain **`APINetWorthHistoryResponse`** via **`APIServiceProtocol`** (injected alongside `DataServiceProtocol`) for online fetches, **encode** the response for `CachedNetWorthHistory`, and map to `[NetWorthSnapshot]` for callers—without changing `DataService` or `APIService` method signatures.

#### CachedTransaction.swift

```swift
@Model
final class CachedTransaction {
    /// Stable key for uniqueness, e.g. "\(userId)|\(transactionId)"
    @Attribute(.unique) var cacheKey: String
    var userId: String
    var transactionId: String  // APIEnrichedTransactionResponse.id
    var data: Data  // Encoded APIEnrichedTransactionResponse
    var lastUpdated: Date
}
```

### 2. NetworkMonitoring

**Location:** `Managers/Offline/NetworkMonitoring.swift` (protocol) + `NWPathNetworkMonitor.swift` (or `NetworkMonitor.swift` for the concrete type)

```swift
/// Abstraction for reachability; fake in unit tests.
@MainActor
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
    // Optional: publisher/async stream if UI binds without singletons
}

final class NWPathNetworkMonitor: NetworkMonitoring, ObservableObject {
    // Wraps NWPathMonitor + DispatchQueue; start from VaultTrackerApp when authenticated if desired
}
```

**Testing:** Do **not** rely on mocking `NWPathMonitor` directly; inject `NetworkMonitoring` fakes that flip `isConnected`.

### 3. OfflineSyncManager

**Location:** `Managers/Offline/OfflineSyncManager.swift`

```swift
@MainActor
final class OfflineSyncManager: ObservableObject {
    static let shared = OfflineSyncManager()

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var pendingCount: Int = 0

    enum SyncStatus {
        case idle
        case syncing(progress: Int, total: Int)
        case failed(count: Int)
    }

    func enqueue(_ request: APISmartTransactionCreateRequest) async throws
    func syncNow() async
    func discardPending(id: UUID) async
}
```

Implements [Sync contract](#sync-contract) together with `PendingTransactionStore` and `DataService.createSmartTransaction`.

### 4. DataRepository

**Location:** `Managers/Offline/DataRepository.swift`

**Responsibilities:**

- **Writes:** If online → `DataService.createSmartTransaction`; if offline → enqueue via `OfflineSyncManager` / `PendingTransactionStore` (exact split is implementation detail; manager may own enqueue).
- **Reads:** Try network via `DataService`; on failure, if cache hit → return domain data + `isStale: true`; if no cache → throw (e.g. `OfflineError.noCachedData`).
- **Cache population:** After **successful** `fetchDashboard`, `fetchHouseholdDashboard`, `fetchAllTransactions`, **`fetchNetWorthHistory(period:)`**, and **`fetchHouseholdNetWorthHistory(period:)`**, **write** the corresponding blobs into `CachedDataStore` (including replacing per-user transaction rows and upserting net worth rows for that `userId` + `period` + scope).

```swift
@MainActor
final class DataRepository: ObservableObject {
    init(
        dataService: DataServiceProtocol = DataService.shared,
        api: APIServiceProtocol = APIService.shared,  // net worth history raw responses for cache population
        syncManager: OfflineSyncManager = .shared,
        network: NetworkMonitoring,
        cache: CachedDataStore = .shared
    )

    func createTransaction(_ request: APISmartTransactionCreateRequest) async throws

    func fetchPersonalDashboard() async throws -> (APIDashboardResponse, isStale: Bool)
    func fetchHouseholdDashboard() async throws -> (APIHouseholdDashboardResponse, isStale: Bool)
    func fetchTransactions() async throws -> ([Transaction], isStale: Bool)

    func fetchPersonalNetWorthHistory(period: APINetWorthPeriod) async throws -> ([NetWorthSnapshot], isStale: Bool)
    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod) async throws -> ([NetWorthSnapshot], isStale: Bool)
}

enum OfflineError: LocalizedError {
    case noCachedData
}
```

`HomeViewModel` continues to choose personal vs household branch; it calls the matching repository method when wired. **`rebuildHistoricalSnapshots()`** should use the repository’s net worth methods so period toggles and household mode respect cache + `isStale` the same way as dashboard loads.

### 5. UI components

#### OfflineBanner.swift

**Location:** `Custom UI Components/OfflineBanner.swift`

Binds to reachability + `OfflineSyncManager` (sync failures, pending counts). Copy per original spec: offline line, failed sync + retry.

#### Integration in VaultTrackerApp

**Location:** `MainView/VaultTrackerApp.swift` — authenticated `mainView`

```swift
private var mainView: some View {
    VStack(spacing: 0) {
        OfflineBanner()
        TabView {
            // existing tabs unchanged
        }
    }
    .tint(VTColors.primary)
    .environmentObject(authManager)
}
```

Start `NWPathNetworkMonitor` (or shared monitor) from app init or when entering `.authenticated`—implementation choice documented in code comments.

### 6. ViewModel changes

**HomeViewModel** (primary consumer in v1):

- Inject **`DataRepository`** (or **`DataRepositoryProtocol`**) for **dashboard + transactions + net worth history + smart create** flows aligned with offline.
- Remaining `DataService` usage (analytics, household CRUD, FIRE, profile, `clearAllData`, etc.) stays as today until scoped later.
- Publish **`isStale`** and **`lastUpdated`** (or equivalent) for UI when reads fall back to SwiftData.
- **`onSave`:** route smart transaction through repository.

## File structure

```
VaultTrackerIOS/VaultTracker/
├── Managers/
│   └── Offline/
│       ├── Models/
│       │   ├── PendingTransaction.swift
│       │   ├── CachedPersonalDashboard.swift
│       │   ├── CachedHouseholdDashboard.swift
│       │   ├── CachedNetWorthHistory.swift
│       │   └── CachedTransaction.swift
│       ├── NetworkMonitoring.swift
│       ├── NWPathNetworkMonitor.swift   // or NetworkMonitor.swift
│       ├── OfflineSyncManager.swift
│       ├── PendingTransactionStore.swift
│       ├── CachedDataStore.swift
│       └── DataRepository.swift
├── Custom UI Components/
│   └── OfflineBanner.swift
├── MainView/
│   └── VaultTrackerApp.swift            # MODIFIED — banner + TabView
└── Home/
    └── HomeViewModel.swift               # MODIFIED — repository injection
```

## Testing strategy

### Unit tests (interleaved with implementation)

| Component | Test file | Key tests |
|-----------|-----------|-----------|
| `PendingTransactionStore` + `CachedDataStore` | `VaultTrackerTests/OfflineStoresTests.swift` (serialized suite) | In-memory SwiftData: pending queue CRUD; personal + household dashboard round-trip; net worth per scope/period; transactions upsert + replace-all; `clearAllCaches` |
| `NetworkMonitoring` fake | Used across tests | Toggle `isConnected` without `NWPathMonitor` |
| `NWPathNetworkMonitor` | Optional integration / manual | Smoke only if needed |
| `OfflineSyncManager` | `OfflineSyncManagerTests.swift` | FIFO, single-flight, classified retries, failure states |
| `DataRepository` | `DataRepositoryTests.swift` | Online vs offline write, dual dashboard cache, net worth cache per period + scope, stale fallback |

### Integration / manual

Same scenarios as before: airplane mode, queue, reconnect, verify API; cache fallback after online load then offline reload.

### Verification command

```bash
cd VaultTrackerIOS && xcodebuild test \
  -project VaultTracker.xcodeproj \
  -scheme VaultTracker \
  -testPlan VaultTrackerUnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Implementation order

1. SwiftData models + migrations note in code
2. `PendingTransactionStore` + tests
3. `CachedDataStore` + tests
4. `NetworkMonitoring` + `NWPathNetworkMonitor` + fake + tests
5. `OfflineSyncManager` + tests
6. `DataRepository` + tests
7. `OfflineBanner` + `VaultTrackerApp` wiring
8. `HomeViewModel` integration + mock updates in `VaultTrackerTests`
9. **Final:** update [`Documentation/VaultTracker System Design.md`](../../../Documentation/VaultTracker%20System%20Design.md) (and iOS `CLAUDE.md` as needed) — see [Updates required](#updates-required)

## Updates required

After the feature is implemented end-to-end:

1. **`Documentation/VaultTracker System Design.md`** — offline architecture, components, online/offline data flow, Firebase/auth interaction with sync.
2. **`VaultTrackerIOS/VaultTracker/CLAUDE.md`** (or module doc) — how to run tests, where offline code lives, verification tips.

## Related plans

- Execution checklist: [`.cursor/plans/ios_offline_support_2026-04-25.plan.md`](../../../.cursor/plans/ios_offline_support_2026-04-25.plan.md)
- Prior review notes: [`.cursor/plans/iOS offline design review-9e2660dc.plan.md`](../../../.cursor/plans/iOS%20offline%20design%20review-9e2660dc.plan.md)
