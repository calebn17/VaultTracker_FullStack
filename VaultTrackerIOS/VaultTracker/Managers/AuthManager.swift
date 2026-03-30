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

    private(set) var user: (any AuthUserInfo)?

    private let authBackend: any FirebaseAuthBackend
    private let notificationCenter: NotificationCenter

    private var authListenerHandle: AuthListenerHandle?
    private var authenticationRequiredObserver: NSObjectProtocol?

    private var cancellables = Set<AnyCancellable>()

    init(
        authBackend: any FirebaseAuthBackend = LiveFirebaseAuthBackend(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.authBackend = authBackend
        self.notificationCenter = notificationCenter
        setupSubscribers()
    }

    deinit {
        if let authListenerHandle {
            authBackend.removeStateDidChangeListener(authListenerHandle)
        }
        if let authenticationRequiredObserver {
            notificationCenter.removeObserver(authenticationRequiredObserver)
        }
    }

    private func setupSubscribers() {
        authListenerHandle = authBackend.addStateDidChangeListener { [weak self] user in
            Task { @MainActor in
                self?.user = user
                self?.authenticationState = user == nil ? .unauthenticated : .authenticated
            }
        }

        authenticationRequiredObserver = notificationCenter.addObserver(
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
        try await authBackend.signIn(with: credentials)
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
            user = nil
            return
        }
#endif
        try authBackend.signOut()
        authenticationState = .unauthenticated
        user = nil
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
