# TODO: Firebase Authentication

## Phase 1: Firebase Setup & Configuration

- [x] Create a new project in the Firebase console.
- [x] Register the iOS app with the Firebase project.
- [x] Download the `GoogleService-Info.plist` file.
- [x] Add the `FirebaseAuth` and `GoogleSignIn` Swift packages to the Xcode project.
- [x] Add the `GoogleService-Info.plist` file to the Xcode project.
- [x] Configure URL schemes for Google Sign-In.

## Phase 2: Authentication Logic

- [x] Create `AuthManager.swift` as an `ObservableObject`.
- [x] Implement `signInWithGoogle()` method in `AuthManager`.
- [x] Implement `signInWithApple()` method in `AuthManager`.
- [x] Implement `signOut()` method in `AuthManager`.
- [x] Add a `@Published` property for the current user in `AuthManager`.
- [x] Provide `AuthManager` as an `EnvironmentObject`.

## Phase 3: UI Implementation

- [x] Create `LoginView.swift` with sign-in buttons.
- [x] Create a `ProfileView.swift` with a logout button.
- [x] Update `VaultTrackerApp.swift` to conditionally show `LoginView` or `ContentView`.

## Phase 4: Finalization

- [x] Test the full authentication flow.
- [x] Review and refactor code as needed.
