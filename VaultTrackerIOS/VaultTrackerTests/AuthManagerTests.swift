//
//  AuthManagerTests.swift
//  VaultTrackerTests
//

import FirebaseAuth
import Foundation
import Testing
@testable import VaultTracker

@Suite("AuthManager", .serialized)
@MainActor
struct AuthManagerTests {

    final class StubAuthUser: AuthUserInfo {
        let uid: String
        let displayName: String?

        init(uid: String = "stub-uid", displayName: String? = "Stub User") {
            self.uid = uid
            self.displayName = displayName
        }
    }

    final class FakeFirebaseAuthBackend: FirebaseAuthBackend {
        private var storedHandle: AuthListenerHandle?
        private var callback: (((any AuthUserInfo)?) -> Void)?

        private(set) var firebaseSignOutCallCount = 0
        private(set) var signInWithCredentialCallCount = 0

        var currentUser: (any AuthUserInfo)?

        /// When `false`, the listener is never invoked (simulates a broken Firebase listener). Default matches Firebase’s immediate callback with cached state.
        var invokeInitialListener = true

        func addStateDidChangeListener(
            _ listener: @escaping ((any AuthUserInfo)?) -> Void
        ) -> AuthListenerHandle {
            callback = listener
            let handle = AuthListenerHandle()
            storedHandle = handle
            if invokeInitialListener {
                listener(currentUser)
            }
            return handle
        }

        func removeStateDidChangeListener(_ handle: AuthListenerHandle) {
            guard handle == storedHandle else { return }
            storedHandle = nil
            callback = nil
        }

        func signOut() throws {
            firebaseSignOutCallCount += 1
        }

        func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
            signInWithCredentialCallCount += 1
            // Do not call Firebase — tests rely on a pure stub. Production uses `LiveFirebaseAuthBackend`.
            throw NSError(
                domain: "FakeFirebaseAuthBackend",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "stub — use LiveFirebaseAuthBackend for a real sign-in"]
            )
        }

        func simulateUser(_ user: (any AuthUserInfo)?) {
            currentUser = user
            callback?(user)
        }
    }

    @Test func stateListenerWithNilUserSetsUnauthenticated() async {
        let fake = FakeFirebaseAuthBackend()
        fake.currentUser = nil
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter())
        await Task.yield()
        #expect(manager.authenticationState == .unauthenticated)
        #expect(manager.user == nil)
    }

    @Test func stateListenerWithUserSetsAuthenticated() async {
        let fake = FakeFirebaseAuthBackend()
        let stub = StubAuthUser()
        fake.currentUser = stub
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter())
        await Task.yield()
        #expect(manager.authenticationState == .authenticated)
        #expect(manager.user?.uid == stub.uid)
        #expect(manager.user?.displayName == stub.displayName)
    }

    @Test func simulateSignOutViaListenerUpdatesState() async {
        let fake = FakeFirebaseAuthBackend()
        fake.currentUser = StubAuthUser()
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter())
        await Task.yield()
        #expect(manager.authenticationState == .authenticated)

        fake.simulateUser(nil)
        await Task.yield()
        #expect(manager.authenticationState == .unauthenticated)
        #expect(manager.user == nil)
    }

    @Test func authenticationRequiredPostsSignOutThroughBackend() async throws {
#if DEBUG
        AuthTokenProvider.shared.isDebugSession = false
#endif
        let spy = VTLoggingSpy()
        let fake = FakeFirebaseAuthBackend()
        fake.currentUser = StubAuthUser()
        let nc = NotificationCenter()
        let manager = AuthManager(authBackend: fake, notificationCenter: nc, log: spy)
        await Task.yield()
        #expect(manager.authenticationState == .authenticated)

        nc.post(name: .authenticationRequired, object: nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(fake.firebaseSignOutCallCount == 1)
        #expect(manager.authenticationState == .unauthenticated)
        #expect(spy.entries.contains { $0.level == .warn && $0.message == "authenticationRequired — signing out" })
        #expect(spy.entries.contains { $0.level == .info && $0.message == "User signed out" })
    }

#if DEBUG
    @Test func signInDebugThenSignOutSkipsFirebaseSignOut() async throws {
        AuthTokenProvider.shared.isDebugSession = false
        let spy = VTLoggingSpy()
        let fake = FakeFirebaseAuthBackend()
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter(), log: spy)
        await Task.yield()

        manager.signInDebug()
        #expect(AuthTokenProvider.shared.isDebugSession == true)
        #expect(manager.authenticationState == .authenticated)

        try manager.signOut()
        #expect(AuthTokenProvider.shared.isDebugSession == false)
        #expect(manager.authenticationState == .unauthenticated)
        #expect(fake.firebaseSignOutCallCount == 0)
        #expect(spy.entries.contains { $0.level == .info && $0.message == "User signed out" })
    }
#endif

    @Test func authListenerTimeoutFallsBackToUnauthenticated() async throws {
        let fake = FakeFirebaseAuthBackend()
        fake.invokeInitialListener = false
        fake.currentUser = nil
        let spy = VTLoggingSpy()
        let manager = AuthManager(
            authBackend: fake,
            notificationCenter: NotificationCenter(),
            log: spy,
            authListenerTimeoutNanoseconds: 100_000_000
        )
        #expect(manager.authenticationState == .authenticating)
        try await Task.sleep(for: .milliseconds(250))
        #expect(manager.authenticationState == .unauthenticated)
        #expect(spy.entries.contains {
            $0.level == .warn && $0.message == "Auth listener timeout — falling back to unauthenticated"
        })
    }

    @Test func signOutLogsInfoThroughBackend() async throws {
#if DEBUG
        AuthTokenProvider.shared.isDebugSession = false
#endif
        let spy = VTLoggingSpy()
        let fake = FakeFirebaseAuthBackend()
        fake.currentUser = StubAuthUser()
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter(), log: spy)
        await Task.yield()

        try manager.signOut()
        #expect(fake.firebaseSignOutCallCount == 1)
        #expect(spy.entries.contains { $0.level == .info && $0.message == "User signed out" })
    }

    @Test func signInWithAppleLogsNotImplementedWarn() async throws {
        let spy = VTLoggingSpy()
        let manager = AuthManager(authBackend: FakeFirebaseAuthBackend(), notificationCenter: NotificationCenter(), log: spy)
        await Task.yield()
        try await manager.signInWithApple()
        #expect(spy.entries.contains { $0.level == .warn && $0.message == "Sign in with Apple not yet implemented" })
    }

    /// Disabled until Google Sign-In can be stubbed (injectable presenter / `GIDSignIn` seam).
    @Test(.disabled("Requires real Google Sign-In / host UI; bypass needs injectable GIDSign-In or Utilities seam."))
    func signInWithGoogleLogsErrorWhenPresentationUnavailable() async throws {
        let spy = VTLoggingSpy()
        let manager = AuthManager(authBackend: FakeFirebaseAuthBackend(), notificationCenter: NotificationCenter(), log: spy)
        await Task.yield()
        await #expect(throws: Error.self) {
            try await manager.signInWithGoogle()
        }
        #expect(spy.entries.contains { $0.level == .error && $0.message == "Sign-in failed" })
    }
}
