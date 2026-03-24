//
//  APIErrorResponse.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

/// Standard error response format from the API
/// All API errors return this structure
struct APIErrorResponse: Codable {
    /// Error message describing what went wrong
    let detail: String
}

/// Validation error response for 422 status codes
/// FastAPI returns this format for request validation errors
struct APIValidationErrorResponse: Codable {
    let detail: [APIValidationErrorDetail]
}

/// Individual validation error detail
struct APIValidationErrorDetail: Codable {
    /// Location of the error (e.g., ["body", "name"])
    let loc: [String]
    /// Error message
    let msg: String
    /// Error type identifier
    let type: String
}
