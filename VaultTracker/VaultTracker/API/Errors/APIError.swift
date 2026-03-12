//
//  APIError.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation

/// All errors that can be thrown by APIService.
///
/// Conforms to `LocalizedError` so SwiftUI alert modifiers and error
/// presentation can use `error.localizedDescription` directly.
enum APIError: LocalizedError {

    /// No Firebase user is currently signed in (thrown by AuthTokenProvider).
    case notAuthenticated

    /// 401 — token was invalid even after a force-refresh; user has been signed out.
    case unauthorized

    /// 403 — authenticated but not allowed to access the resource.
    case forbidden

    /// 404 — the requested resource does not exist.
    case notFound

    /// 422 — request was well-formed but failed server validation.
    /// Associated value contains field-level error messages from FastAPI.
    case validationError([String])

    /// 5xx — the server encountered an unexpected error.
    case serverError(Int)

    /// Transport-level failure (no network, DNS error, timeout, etc.).
    case networkError(Error)

    /// The server returned a response body that couldn't be decoded.
    case decodingError(Error)

    /// An unexpected HTTP status code not covered by the cases above.
    case unknown(Int)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in. Please sign in and try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested item could not be found."
        case .validationError(let messages):
            return messages.isEmpty
                ? "The request contained invalid data."
                : "Invalid data: \(messages.joined(separator: ", "))."
        case .serverError(let code):
            return "A server error occurred (code \(code)). Please try again later."
        case .networkError:
            return "A network error occurred. Check your connection and try again."
        case .decodingError:
            return "Received an unexpected response from the server."
        case .unknown(let code):
            return "An unexpected error occurred (code \(code))."
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension APIError {

    /// Map an HTTP status code (and optional response data) to the appropriate APIError.
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - data: Raw response body, used to extract validation error details on 422.
    ///   - decoder: The JSONDecoder to use when parsing validation errors.
    static func from(statusCode: Int, data: Data, decoder: JSONDecoder) -> APIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 422:
            let messages = parseValidationMessages(from: data, decoder: decoder)
            return .validationError(messages)
        case 500...599:
            return .serverError(statusCode)
        default:
            return .unknown(statusCode)
        }
    }

    /// Attempts to decode a FastAPI 422 validation response and flatten
    /// the per-field error messages into a plain string array.
    private static func parseValidationMessages(from data: Data, decoder: JSONDecoder) -> [String] {
        guard let response = try? decoder.decode(APIValidationErrorResponse.self, from: data) else {
            return []
        }
        return response.detail.map { "\($0.loc.last ?? "field"): \($0.msg)" }
    }
}
