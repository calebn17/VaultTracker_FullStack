//
//  AuthTokenProviderTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

@Suite("AuthTokenProvider", .serialized)
struct AuthTokenProviderTests {

    /// Debug-session forced refresh failure should throw before any Firebase or logging path.
    @Test func debugForceRefreshFailureThrowsWithoutLogging() async throws {
        let spy = VTLoggingSpy()
        let provider = AuthTokenProvider.test_make(log: spy)
        provider.isDebugSession = true
        provider.forceTokenRefreshFailure = true

        await #expect(throws: AuthTokenError.self) {
            try await provider.getToken(forceRefresh: true)
        }
        #expect(spy.entries.isEmpty)
    }
}

// Debug-token fast path (`isDebugSession`) is covered indirectly via `APIServiceTests` + `withDebugSession`.
// Force-refresh warn and “Token fetch failed” on the Firebase callback are covered by `APIServiceTests`
// (401 retry / refresh failure) and manual runs with a real session.
