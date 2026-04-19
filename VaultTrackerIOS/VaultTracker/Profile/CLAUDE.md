# Profile

Settings/account screen.

> **Dependencies, extending guidance:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File | Role |
|------|------|
| `ProfileView.swift` | SwiftUI view — welcome message + sign-out button |

## Current Functionality

- Displays `authManager.user?.displayName` from Firebase
- Sign Out calls `authManager.signOut()` → sets `authenticationState = .unauthenticated` → `VaultTrackerApp` transitions to `LoginView`
