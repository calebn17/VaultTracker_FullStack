//
//  FirebaseAuthBackend.swift
//  VaultTracker
//
//  Abstraction over Firebase Auth for testability. Live implementation
//  delegates to Auth.auth(); unit tests inject FakeFirebaseAuthBackend.

import Foundation
import FirebaseAuth

/// Minimal user surface needed by the app shell (e.g. ProfileView).
protocol AuthUserInfo: AnyObject {
    var uid: String { get }
    var displayName: String? { get }
}

extension User: AuthUserInfo {}

/// Handle returned when registering an auth state listener; used to remove it in `deinit`.
struct AuthListenerHandle: Hashable, Sendable {
    fileprivate let id: UUID
    fileprivate init(id: UUID) { self.id = id }
    init() { id = UUID() }
}

protocol FirebaseAuthBackend: AnyObject {
    @discardableResult
    func addStateDidChangeListener(
        _ listener: @escaping ((any AuthUserInfo)?) -> Void
    ) -> AuthListenerHandle

    func removeStateDidChangeListener(_ handle: AuthListenerHandle)
    func signOut() throws
    @discardableResult
    func signIn(with credential: AuthCredential) async throws -> AuthDataResult
}

final class LiveFirebaseAuthBackend: FirebaseAuthBackend {
    private var firebaseHandles: [UUID: AuthStateDidChangeListenerHandle] = [:]
    private let mapLock = NSLock()

    func addStateDidChangeListener(
        _ listener: @escaping ((any AuthUserInfo)?) -> Void
    ) -> AuthListenerHandle {
        let handle = AuthListenerHandle()
        let fbHandle = Auth.auth().addStateDidChangeListener { _, user in
            listener(user)
        }
        mapLock.lock()
        firebaseHandles[handle.id] = fbHandle
        mapLock.unlock()
        return handle
    }

    func removeStateDidChangeListener(_ handle: AuthListenerHandle) {
        mapLock.lock()
        let fbHandle = firebaseHandles.removeValue(forKey: handle.id)
        mapLock.unlock()
        if let fbHandle {
            Auth.auth().removeStateDidChangeListener(fbHandle)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await Auth.auth().signIn(with: credential)
    }
}

/// No-op auth backend used only when running XCTest host app bootstrapping.
final class TestFirebaseAuthBackend: FirebaseAuthBackend {
    @discardableResult
    func addStateDidChangeListener(
        _ listener: @escaping ((any AuthUserInfo)?) -> Void
    ) -> AuthListenerHandle {
        listener(nil)
        return AuthListenerHandle()
    }

    func removeStateDidChangeListener(_ handle: AuthListenerHandle) {}

    func signOut() throws {}

    enum TestBackendError: Error {
        case signInUnavailable
    }

    func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        throw TestBackendError.signInUnavailable
    }
}
