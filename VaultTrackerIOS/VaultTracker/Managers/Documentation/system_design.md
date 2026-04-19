# Managers — System Design

## Responsibility Split

| Layer         | Knows about                                                      |
| ------------- | ---------------------------------------------------------------- |
| `APIService`  | `URLRequest`, `URLSession`, HTTP status codes, Codable API types |
| `DataService` | Domain models (`Transaction`, `Asset`, `Account`), Mapper calls  |
| ViewModels    | `DataServiceProtocol` only — never `APIService` directly         |

## DataService Protocol Surface

| Method                          | Delegates to                                                 |
| ------------------------------- | ------------------------------------------------------------ |
| `fetchDashboard()`              | `api.fetchDashboard()`                                       |
| `fetchAnalytics()`              | `api.fetchAnalytics()`                                       |
| `refreshPrices()`               | `api.refreshPrices()`                                        |
| `fetchAllTransactions()`        | `api.fetchTransactions()` → `TransactionMapper.toDomain(_:)` |
| `createSmartTransaction(_:)`    | `api.createSmartTransaction(_:)` (discards response)         |
| `deleteTransaction(id:)`        | `api.deleteTransaction(id:)`                                 |
| `fetchAllAssets()`              | `api.fetchAssets()` → `AssetMapper.toDomain(_:)`             |
| `createAsset(_:)`               | `api.createAsset(_:)` → `AssetMapper.toDomain(_:)`           |
| `fetchAllAccounts()`            | `api.fetchAccounts()` → `AccountMapper.toDomain(_:)`         |
| `createAccount(_:)`             | `api.createAccount(_:)` → `AccountMapper.toDomain(_:)`       |
| `updateAccount(id:_:)`          | `api.updateAccount(id:_:)` → `AccountMapper.toDomain(_:)`    |
| `deleteAccount(id:)`            | `api.deleteAccount(id:)`                                     |
| `fetchNetWorthHistory(period:)` | `api.fetchNetWorthHistory(period:)` → `[NetWorthSnapshot]`   |
| `clearAllData()`                | `api.clearAllData()`                                         |

`fetchAllTransactions` returns `[APIEnrichedTransactionResponse]` with inline asset and account data — no parallel fetch needed.

## AuthManager Internals

`@MainActor ObservableObject` injected as `@EnvironmentObject` at root. Depends on:

- **`FirebaseAuthBackend`** (default `LiveFirebaseAuthBackend` → `Auth.auth()`)
- **`NotificationCenter`** (default `.default`)

`init(authBackend:notificationCenter:log:)` enables unit tests with `FakeFirebaseAuthBackend`, isolated `NotificationCenter()`, and optional `VTLogging`. 5-second watchdog fires if the auth listener never runs.

`FirebaseAuthBackend.signIn(with:)` returns `AuthDataResult` so `signInWithGoogle()` can log `result.user.uid` without re-reading `Auth.auth().currentUser`.

Also observes `Notification.Name.authenticationRequired` (posted by `APIService` after persistent 401) to trigger automatic sign-out. Listener and notification observer removed in `deinit`.
