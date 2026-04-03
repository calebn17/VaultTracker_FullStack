//
//  AuthTokenProvider.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation
import FirebaseAuth

/// Thread-safe actor that retrieves the current user's Firebase JWT for API authentication.
///
/// In DEBUG builds, `AuthManager.signInDebug()` sets `isDebugSession = true`, which
/// causes `getToken()` to return a hardcoded token (`"vaulttracker-debug-user"`). The
/// backend maps that token to a fixed `"debug-user"` row when `DEBUG_AUTH_ENABLED=true`
/// in its `.env`, eliminating the need for a real Firebase account during local testing.
actor AuthTokenProvider {

    private let log: any VTLogging

    private init(log: any VTLogging = VTLog.shared) {
        self.log = log
    }

    static let shared = AuthTokenProvider()

    /// Custom logger; same behavior as ``shared``. Intended for `VaultTrackerTests` via `@testable import` only.
    internal static func test_make(log: any VTLogging) -> AuthTokenProvider {
        AuthTokenProvider(log: log)
    }

#if DEBUG
    /// Toggled by `AuthManager.signInDebug()`. When `true`, all API calls skip Firebase
    /// and use the well-known debug token that the backend's dependency.py recognises.
    nonisolated(unsafe) var isDebugSession = false
    static let debugToken = "vaulttracker-debug-user"

    /// When `true` (only honored for `isDebugSession` + `getToken(forceRefresh: true)`), forces token failure so `APIService` retry paths can be unit-tested without Firebase.
    nonisolated(unsafe) var forceTokenRefreshFailure = false
#endif

    /// Returns the current user's ID token.
    /// - Parameter forceRefresh: Pass `true` to force Firebase to fetch a new
    ///   token from the server (used after a 401 response). Pass `false` to
    ///   use the cached token if it hasn't expired yet (< 1 hour old).
    func getToken(forceRefresh: Bool = false) async throws -> String {
#if DEBUG
        if isDebugSession {
            if forceRefresh && forceTokenRefreshFailure {
                throw AuthTokenError.notAuthenticated
            }
            return AuthTokenProvider.debugToken
        }
#endif
        guard let user = Auth.auth().currentUser else {
            throw AuthTokenError.notAuthenticated
        }
        return try await withCheckedThrowingContinuation { continuation in
            if forceRefresh {
                self.log.warn("Force-refreshing token after 401", category: .auth)
            }
            user.getIDTokenForcingRefresh(forceRefresh) { [self] token, error in
                if let token = token {
                    continuation.resume(returning: token)
                } else {
                    let thrown = error ?? AuthTokenError.notAuthenticated
                    self.log.error("Token fetch failed", error: thrown, category: .auth)
                    continuation.resume(throwing: thrown)
                }
            }
        }
    }
}

// MARK: - AuthTokenError

enum AuthTokenError: Error {
    /// No Firebase user is currently signed in.
    case notAuthenticated
}
