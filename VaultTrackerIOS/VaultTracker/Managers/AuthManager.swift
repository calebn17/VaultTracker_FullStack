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
    private let log: any VTLogging

    private var authListenerHandle: AuthListenerHandle?
    private var authenticationRequiredObserver: NSObjectProtocol?
    private var authTimeoutTask: Task<Void, Never>?

    /// If Firebase never invokes the auth state listener (broken SDK edge case), fall back after this delay.
    /// `nil` disables (tests only).
    private let authListenerTimeoutNanoseconds: UInt64?

    private var cancellables = Set<AnyCancellable>()

    init(
        authBackend: any FirebaseAuthBackend = LiveFirebaseAuthBackend(),
        notificationCenter: NotificationCenter = .default,
        log: any VTLogging = VTLog.shared,
        authListenerTimeoutNanoseconds: UInt64? = 5_000_000_000
    ) {
        self.authBackend = authBackend
        self.notificationCenter = notificationCenter
        self.log = log
        self.authListenerTimeoutNanoseconds = authListenerTimeoutNanoseconds
        setupSubscribers()
        scheduleAuthListenerTimeout()
    }

    deinit {
        authTimeoutTask?.cancel()
        if let authListenerHandle {
            authBackend.removeStateDidChangeListener(authListenerHandle)
        }
        if let authenticationRequiredObserver {
            notificationCenter.removeObserver(authenticationRequiredObserver)
        }
    }

    private func cancelAuthListenerTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
    }

    private func scheduleAuthListenerTimeout() {
        guard let nanos = authListenerTimeoutNanoseconds else { return }
        cancelAuthListenerTimeout()
        authTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard let self else { return }
            guard authenticationState == .authenticating else { return }
            log.warn("Auth listener timeout — falling back to unauthenticated", category: .auth)
            authenticationState = .unauthenticated
        }
    }

    private func setupSubscribers() {
        authListenerHandle = authBackend.addStateDidChangeListener { [weak self] user in
            Task { @MainActor in
                self?.cancelAuthListenerTimeout()
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
                self?.log.warn("authenticationRequired — signing out", category: .auth)
                try? self?.signOut()
            }
        }
    }

    func signInWithGoogle() async throws {
        do {
            guard let topVC = Utilities.shared.getTopViewController() else {
                throw URLError(.cannotFindHost)
            }

            let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)

            guard let idToken = gidSignInResult.user.idToken?.tokenString else {
                throw URLError(.badServerResponse)
            }

            let accessToken = gidSignInResult.user.accessToken.tokenString
            let credentials = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let result = try await authBackend.signIn(with: credentials)
            log.info("User signed in", category: .auth, context: ["uid": result.user.uid])
        } catch {
            log.error("Sign-in failed", error: error, category: .auth)
            throw error
        }
    }

    func signInWithApple() async throws {
        // TODO: Implement Sign in with Apple
        log.warn("Sign in with Apple not yet implemented", category: .auth)
    }

    func signOut() throws {
        log.info("User signed out", category: .auth)
#if DEBUG
        if AuthTokenProvider.shared.isDebugSession {
            AuthTokenProvider.shared.isDebugSession = false
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
        cancelAuthListenerTimeout()
        AuthTokenProvider.shared.isDebugSession = true
        authenticationState = .authenticated
    }
#endif
}
