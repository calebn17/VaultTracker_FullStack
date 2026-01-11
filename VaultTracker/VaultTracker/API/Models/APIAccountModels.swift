//
//  APIAccountModels.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

// MARK: - Response Models

/// Response model for account endpoints
/// Used by: GET /api/v1/accounts, GET /api/v1/accounts/{id}, POST /api/v1/accounts, PUT /api/v1/accounts/{id}
struct APIAccountResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let accountType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case accountType = "account_type"
        case createdAt = "created_at"
    }
}

// MARK: - Request Models

/// Request model for creating a new account
/// Used by: POST /api/v1/accounts
struct APIAccountCreateRequest: Codable {
    let name: String
    let accountType: String

    enum CodingKeys: String, CodingKey {
        case name
        case accountType = "account_type"
    }
}

/// Request model for updating an existing account
/// Used by: PUT /api/v1/accounts/{id}
/// All fields are optional - only include fields to update
struct APIAccountUpdateRequest: Codable {
    let name: String?
    let accountType: String?

    enum CodingKeys: String, CodingKey {
        case name
        case accountType = "account_type"
    }

    init(name: String? = nil, accountType: String? = nil) {
        self.name = name
        self.accountType = accountType
    }
}

// MARK: - Account Types

/// Valid account type values accepted by the API
enum APIAccountType: String, Codable, CaseIterable {
    case cryptoExchange
    case brokerage
    case bank
    case retirement
    case other
}
