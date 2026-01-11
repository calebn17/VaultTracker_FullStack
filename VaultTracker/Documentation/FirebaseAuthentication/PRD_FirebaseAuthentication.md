# PRD: Firebase Authentication

## 1. Overview

This feature integrates Firebase Authentication to provide a secure and scalable user authentication layer for the VaultTracker application. Implementing this feature is the first step towards creating personalized user experiences and is a prerequisite for future features like cloud data synchronization and AI-powered financial insights.

Initially, the focus will be on enabling sign-in via popular third-party providers.

## 2. Key Features & Requirements

### User-Facing Features

-   **Login View:** A new view will be presented to unauthenticated users, offering one or more sign-in options.
-   **Sign-In with Google:** Users will be able to sign in or create an account using their Google account.
-   **Sign-In with Apple:** Users will be able to sign in or create an account using their Apple ID, as per App Store guidelines.
-   **Logout Functionality:** Authenticated users will have a button, likely in a settings or profile view, to log out of their account.

### Technical Requirements

-   **Firebase Project Setup:** A new Firebase project must be created and linked to the iOS application.
-   **Firebase SDK Integration:** The necessary Firebase Authentication SDKs will be added to the project using Swift Package Manager.
-   **Configuration Files:** The `GoogleService-Info.plist` file from Firebase must be correctly included in the Xcode project.
-   **Authentication Logic:** A new `AuthManager` class will be created to handle all interactions with the Firebase Auth SDK, including sign-in, sign-out, and checking the current user's authentication state.
-   **View Routing:** The main application view (`VaultTrackerApp.swift`) will be updated to conditionally display either the `LoginView` or the `MainView` based on the user's authentication state.

## 3. Implementation Plan

### Phase 1: Firebase Setup & Configuration

1.  **Firebase Project:** Create a new project in the Firebase console.
2.  **Register App:** Register the iOS app with the Firebase project, providing the correct bundle ID.
3.  **Download Config File:** Download the `GoogleService-Info.plist` file.
4.  **Add SDKs:** Add the `FirebaseAuth` and `GoogleSignIn` Swift packages to the Xcode project.
5.  **Configure Project:** Add the `GoogleService-Info.plist` file to the Xcode project and configure the URL schemes for Google Sign-In.

### Phase 2: Authentication Logic

1.  **Create `AuthManager`:** Develop a new `AuthManager.swift` class to encapsulate all Firebase interactions.
    -   It will be an `ObservableObject` to publish the user's authentication state.
    -   It will include methods for `signInWithGoogle()`, `signInWithApple()`, and `signOut()`.
    -   It will expose a `@Published` property to indicate the current authenticated user.
2.  **Integrate `AuthManager`:** Provide the `AuthManager` as an `EnvironmentObject` to the SwiftUI view hierarchy.

### Phase 3: UI Implementation

1.  **Create `LoginView`:** Design and build a new SwiftUI view that presents the "Sign in with Google" and "Sign in with Apple" buttons.
2.  **Create Profile/Settings View:** Create a simple view where the "Logout" button will reside.
3.  **Update App Entry Point:** Modify `VaultTrackerApp.swift` to observe the `AuthManager`'s state and show the `LoginView` if the user is not authenticated, or the main `ContentView` if they are.

## 4. Future Refactoring & Improvements

-   **`AuthManager.swift` - Error Handling:** Consider implementing more specific custom error types instead of generic `URLError` for better clarity and debugging.
-   **`ProfileView.swift` - Display Name:** Explore more robust ways to handle and display user information (e.g., allowing users to set custom display names) beyond just `displayName` from Firebase.
-   **`LoginView.swift` - Apple Sign-In Implementation:** Fully implement the Sign in with Apple flow, including handling `ASAuthorizationControllerDelegate` and associated callbacks.
