//
//  APITransactionModels.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

// MARK: - Response Models

/// Response model for transaction endpoints
/// Used by: GET /api/v1/transactions, GET /api/v1/transactions/{id}, POST /api/v1/transactions, PUT /api/v1/transactions/{id}
struct APITransactionResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let assetId: String
    let accountId: String
    let transactionType: String
    let quantity: Double
    let pricePerUnit: Double
    let date: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case assetId = "asset_id"
        case accountId = "account_id"
        case transactionType = "transaction_type"
        case quantity
        case pricePerUnit = "price_per_unit"
        case date
    }
}

// MARK: - Request Models

/// Request model for creating a new transaction
/// Used by: POST /api/v1/transactions
struct APITransactionCreateRequest: Codable {
    let assetId: String
    let accountId: String
    let transactionType: String
    let quantity: Double
    let pricePerUnit: Double
    let date: Date?

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case accountId = "account_id"
        case transactionType = "transaction_type"
        case quantity
        case pricePerUnit = "price_per_unit"
        case date
    }

    init(
        assetId: String,
        accountId: String,
        transactionType: String,
        quantity: Double,
        pricePerUnit: Double,
        date: Date? = nil
    ) {
        self.assetId = assetId
        self.accountId = accountId
        self.transactionType = transactionType
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.date = date
    }
}

/// Request model for updating an existing transaction
/// Used by: PUT /api/v1/transactions/{id}
/// All fields are optional - only include fields to update
struct APITransactionUpdateRequest: Codable {
    let transactionType: String?
    let quantity: Double?
    let pricePerUnit: Double?
    let date: Date?

    enum CodingKeys: String, CodingKey {
        case transactionType = "transaction_type"
        case quantity
        case pricePerUnit = "price_per_unit"
        case date
    }

    init(
        transactionType: String? = nil,
        quantity: Double? = nil,
        pricePerUnit: Double? = nil,
        date: Date? = nil
    ) {
        self.transactionType = transactionType
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.date = date
    }
}

// MARK: - Transaction Types

/// Valid transaction type values accepted by the API
enum APITransactionType: String, Codable, CaseIterable {
    case buy
    case sell
}
