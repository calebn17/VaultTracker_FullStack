# Login

Entry screen shown when `AuthManager.authenticationState == .unauthenticated`.

> **Navigation pattern, debug login details, styling:** [`Documentation/system_design.md`](../Documentation/system_design.md)

## Files

| File              | Role             |
| ----------------- | ---------------- |
| `LoginView.swift` | SwiftUI login UI |

## Auth Methods

| Button         | Status                                                                   |
| -------------- | ------------------------------------------------------------------------ |
| Google Sign-In | Implemented — calls `AuthManager.signInWithGoogle()`                     |
| Debug Login    | DEBUG builds only — calls `AuthManager.signInDebug()`, bypasses Firebase |

Apple Sign-In is not shown until implemented end-to-end.
