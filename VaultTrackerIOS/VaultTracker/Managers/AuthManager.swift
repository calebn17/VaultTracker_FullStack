//
//  AuthManager.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/17/25.
//

// Manages Firebase authentication state and publishes it to the UI via
// `authenticationState`. Also observes the `.authenticationRequired` notification
// posted by APIService when a 401 persists after token refresh, triggering auto sign-out.
// In DEBUG builds, `signInDebug()` sets `AuthTokenProvider.isDebugSession = true` for
// passwordless local testing — no Firebase account required.

import Foundation
import FirebaseAuth
import GoogleSignIn
import Combine

enum AuthenticationState {
    /// Fetching auth state of user
    case authenticating
    /// User is authenticated
    case authenticated
    /// User is not authenticated
    case unauthenticated
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var authenticationState: AuthenticationState = .authenticating
    
    var user: User?
    private var cancellables = Set<AnyCancellable>()
    
    
    init() {
        setupSubscribers()
    }

    private func setupSubscribers() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.authenticationState = user == nil ? .unauthenticated : .authenticated
        }

        NotificationCenter.default.addObserver(
            forName: .authenticationRequired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? self?.signOut()
            }
        }
    }
    
    func signInWithGoogle() async throws {
        guard let topVC = Utilities.shared.getTopViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = gidSignInResult.user.accessToken.tokenString
        let credentials = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let _ = try await Auth.auth().signIn(with: credentials)
    }
    
    func signInWithApple() async throws {
        // TODO: Implement Sign in with Apple
        print("Sign in with Apple not yet implemented")
    }
    
    func signOut() throws {
#if DEBUG
        if AuthTokenProvider.isDebugSession {
            AuthTokenProvider.isDebugSession = false
            authenticationState = .unauthenticated
            return
        }
#endif
        try Auth.auth().signOut()
        authenticationState = .unauthenticated
    }

#if DEBUG
    /// Bypasses Firebase and marks the session as authenticated using a
    /// well-known debug token.  Only available in DEBUG builds; requires
    /// DEBUG_AUTH_ENABLED=true in the backend .env.
    func signInDebug() {
        AuthTokenProvider.isDebugSession = true
        authenticationState = .authenticated
    }
#endif
}
