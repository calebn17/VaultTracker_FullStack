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

        func addStateDidChangeListener(
            _ listener: @escaping ((any AuthUserInfo)?) -> Void
        ) -> AuthListenerHandle {
            callback = listener
            let handle = AuthListenerHandle()
            storedHandle = handle
            listener(currentUser)
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

        func signIn(with credential: AuthCredential) async throws {
            signInWithCredentialCallCount += 1
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
        AuthTokenProvider.isDebugSession = false
#endif
        let fake = FakeFirebaseAuthBackend()
        fake.currentUser = StubAuthUser()
        let nc = NotificationCenter()
        let manager = AuthManager(authBackend: fake, notificationCenter: nc)
        await Task.yield()
        #expect(manager.authenticationState == .authenticated)

        nc.post(name: .authenticationRequired, object: nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(fake.firebaseSignOutCallCount == 1)
        #expect(manager.authenticationState == .unauthenticated)
    }

#if DEBUG
    @Test func signInDebugThenSignOutSkipsFirebaseSignOut() async throws {
        AuthTokenProvider.isDebugSession = false
        let fake = FakeFirebaseAuthBackend()
        let manager = AuthManager(authBackend: fake, notificationCenter: NotificationCenter())
        await Task.yield()

        manager.signInDebug()
        #expect(AuthTokenProvider.isDebugSession == true)
        #expect(manager.authenticationState == .authenticated)

        try manager.signOut()
        #expect(AuthTokenProvider.isDebugSession == false)
        #expect(manager.authenticationState == .unauthenticated)
        #expect(fake.firebaseSignOutCallCount == 0)
    }
#endif
}
