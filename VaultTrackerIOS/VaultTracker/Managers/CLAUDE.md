# Managers

Application-layer services that ViewModels depend on. No SwiftUI code lives here.

> **DataService protocol surface, AuthManager internals, responsibility split:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File                        | Role                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------- |
| `AuthManager.swift`         | Firebase auth state machine, `@EnvironmentObject`; 5s watchdog if auth listener never fires |
| `FirebaseAuthBackend.swift` | `FirebaseAuthBackend` protocol, `AuthUserInfo`, `LiveFirebaseAuthBackend` — test seams      |
| `DataService.swift`         | Concrete `DataServiceProtocol`; delegates all I/O to `APIService`                           |
| `DataServiceProtocol.swift` | Interface ViewModels code against; enables mock testing                                     |
| `NetworkService.swift`      | Legacy URLSession wrapper — **do not use for new work**                                     |

## Adding a New Protocol Method

1. Declare the method on `DataServiceProtocol`
2. Implement it in `DataService` (delegate to `APIService`)
3. Add a stub to `MockDataService` in the test target
