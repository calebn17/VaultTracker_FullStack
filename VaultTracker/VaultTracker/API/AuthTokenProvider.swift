//
//  AuthTokenProvider.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation
import FirebaseAuth

/// Thread-safe provider for the current user's Firebase JWT token.
///
/// Declared as an `actor` so concurrent async callers cannot race when
/// requesting or refreshing the token.
actor AuthTokenProvider {

    static let shared = AuthTokenProvider()

    private init() {}

    /// Returns the current user's ID token.
    /// - Parameter forceRefresh: Pass `true` to force Firebase to fetch a new
    ///   token from the server (used after a 401 response). Pass `false` to
    ///   use the cached token if it hasn't expired yet (< 1 hour old).
    func getToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthTokenError.notAuthenticated
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forceRefresh) { token, error in
                if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: error ?? AuthTokenError.notAuthenticated)
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
