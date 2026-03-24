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

// MARK: - Smart transaction (POST /transactions/smart)

/// Request for server-side account + asset resolution (Backend 2.0).
struct APISmartTransactionCreateRequest: Codable {
    let transactionType: String
    let category: String
    let assetName: String
    let symbol: String?
    let quantity: Double
    let pricePerUnit: Double
    let accountName: String
    let accountType: String
    let date: Date?

    enum CodingKeys: String, CodingKey {
        case transactionType = "transaction_type"
        case category
        case assetName = "asset_name"
        case symbol
        case quantity
        case pricePerUnit = "price_per_unit"
        case accountName = "account_name"
        case accountType = "account_type"
        case date
    }
}

// MARK: - Enriched list response (GET /transactions)

struct APIAssetSummary: Codable {
    let id: String
    let name: String
    let symbol: String?
    let category: String
}

struct APIAccountSummary: Codable {
    let id: String
    let name: String
    let accountType: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case accountType = "account_type"
    }
}

struct APIEnrichedTransactionResponse: Codable {
    let id: String
    let userId: String
    let assetId: String
    let accountId: String
    let transactionType: String
    let quantity: Double
    let pricePerUnit: Double
    let totalValue: Double
    let date: Date
    let asset: APIAssetSummary
    let account: APIAccountSummary

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case assetId = "asset_id"
        case accountId = "account_id"
        case transactionType = "transaction_type"
        case quantity
        case pricePerUnit = "price_per_unit"
        case totalValue = "total_value"
        case date
        case asset
        case account
    }
}

// MARK: - Transaction Types

/// Valid transaction type values accepted by the API
enum APITransactionType: String, Codable, CaseIterable {
    case buy
    case sell
}
