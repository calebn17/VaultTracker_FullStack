//
//  AuthTokenProviderTests.swift
//  VaultTrackerTests
//

import FirebaseAuth
import Foundation
import Testing
@testable import VaultTracker

@Suite("AuthTokenProvider", .serialized)
struct AuthTokenProviderTests {

    /// No Firebase user: fails at the guard before any `log` calls or `getIDTokenForcingRefresh`.
    @Test func noSignedInUserThrowsBeforeFirebasePathWithoutLogging() async throws {
        let spy = VTLoggingSpy()
        let provider = AuthTokenProvider.test_make(log: spy)
        try Auth.auth().signOut()

        await #expect(throws: AuthTokenError.self) {
            try await provider.getToken()
        }
        #expect(spy.entries.isEmpty)
    }
}

// Debug-token fast path (`isDebugSession`) is covered indirectly via `APIServiceTests` + `withDebugSession`.
// Force-refresh warn and “Token fetch failed” on the Firebase callback are covered by `APIServiceTests`
// (401 retry / refresh failure) and manual runs with a real session.
