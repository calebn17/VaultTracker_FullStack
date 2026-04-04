# Managers

Application-layer services that ViewModels depend on. No SwiftUI code lives here.

## Files

| File | Role |
|------|------|
| `AuthManager.swift` | Firebase auth state machine, exposed as `@EnvironmentObject` |
| `FirebaseAuthBackend.swift` | `FirebaseAuthBackend` protocol, `AuthUserInfo`, `LiveFirebaseAuthBackend` — test seams for auth |
| `DataService.swift` | Concrete `DataServiceProtocol` — delegates all I/O to `APIService` |
| `DataServiceProtocol.swift` | Interface ViewModels code against; enables lightweight mock testing |
| `NetworkService.swift` | Legacy URLSession wrapper — **do not use for new work** (see below) |

## DataService

`@MainActor` singleton that satisfies `DataServiceProtocol`. All methods are `async throws`.

### Responsibility split

| Layer | Knows about |
|-------|------------|
| `APIService` | `URLRequest`, `URLSession`, HTTP status codes, Codable API types |
| `DataService` | Domain models (`Transaction`, `Asset`, `Account`), Mapper calls |
| ViewModels | `DataServiceProtocol` only — never `APIService` directly |

### Protocol surface

| Method | Delegates to |
|--------|-------------|
| `fetchDashboard()` | `api.fetchDashboard()` |
| `fetchAnalytics()` | `api.fetchAnalytics()` |
| `refreshPrices()` | `api.refreshPrices()` |
| `fetchAllTransactions()` | `api.fetchTransactions()` → `TransactionMapper.toDomain(_:)` |
| `createSmartTransaction(_:)` | `api.createSmartTransaction(_:)` (discards response) |
| `deleteTransaction(id:)` | `api.deleteTransaction(id:)` |
| `fetchAllAssets()` | `api.fetchAssets()` → `AssetMapper.toDomain(_:)` |
| `createAsset(_:)` | `api.createAsset(_:)` → `AssetMapper.toDomain(_:)` |
| `fetchAllAccounts()` | `api.fetchAccounts()` → `AccountMapper.toDomain(_:)` |
| `createAccount(_:)` | `api.createAccount(_:)` → `AccountMapper.toDomain(_:)` |
| `updateAccount(id:_:)` | `api.updateAccount(id:_:)` → `AccountMapper.toDomain(_:)` |
| `deleteAccount(id:)` | `api.deleteAccount(id:)` |
| `fetchNetWorthHistory(period:)` | `api.fetchNetWorthHistory(period:)` → `[NetWorthSnapshot]` |
| `clearAllData()` | `api.clearAllData()` |

### fetchAllTransactions

Single `api.fetchTransactions()` call — returns `[APIEnrichedTransactionResponse]` with inline asset and account data. `TransactionMapper.toDomain(_:)` converts directly. No parallel fetch needed.

### clearAllData

Calls `DELETE /api/v1/users/me/data`. Used by integration tests to reset server state between runs. Destructive — do not call from production UI without a confirmation dialog.

## AuthManager

`@MainActor ObservableObject` injected as an `@EnvironmentObject` at the root. Depends on **`FirebaseAuthBackend`** (default `LiveFirebaseAuthBackend` → `Auth.auth()`) and **`NotificationCenter`** (default `.default` so `APIService`’s `.authenticationRequired` post is received). `FirebaseAuthBackend.signIn(with:)` returns **`AuthDataResult`** so `signInWithGoogle()` can log `result.user.uid` without re-reading `Auth.auth().currentUser`. Publishes `authenticationState` and `user: (any AuthUserInfo)?` (Firebase `User` conforms in production).

`init(authBackend:notificationCenter:log:)` enables unit tests with `FakeFirebaseAuthBackend`, an isolated `NotificationCenter()`, and an optional `VTLogging` (default `VTLog.shared`). Auth lifecycle events (sign-in success/failure, sign-out, `authenticationRequired`) use the injected logger. Listener and notification observer are removed in `deinit`.

Also observes `Notification.Name.authenticationRequired` (posted by `APIService` after a persistent 401) to trigger automatic sign-out.

## NetworkService (Legacy)

Thin `URLSession` wrapper that uses `[String: String]` bodies. Cannot encode typed `Codable` structs. **Do not add new API calls here.** It remains only for any legacy paths not yet migrated.

## Adding a New Protocol Method

1. Declare the method on `DataServiceProtocol`.
2. Implement it in `DataService` (delegate to `APIService`).
3. Add a stub to `MockDataService` in the test target.
