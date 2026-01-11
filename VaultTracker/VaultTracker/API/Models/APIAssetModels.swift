//
//  APIAssetModels.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

// MARK: - Response Models

/// Response model for asset endpoints
/// Used by: GET /api/v1/assets, GET /api/v1/assets/{id}, POST /api/v1/assets
struct APIAssetResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let symbol: String?
    let category: String
    let quantity: Double
    let currentValue: Double
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case symbol
        case category
        case quantity
        case currentValue = "current_value"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Request Models

/// Request model for creating a new asset
/// Used by: POST /api/v1/assets
struct APIAssetCreateRequest: Codable {
    let name: String
    let symbol: String?
    let category: String
    let quantity: Double
    let currentValue: Double

    enum CodingKeys: String, CodingKey {
        case name
        case symbol
        case category
        case quantity
        case currentValue = "current_value"
    }

    init(
        name: String,
        symbol: String? = nil,
        category: String,
        quantity: Double = 0.0,
        currentValue: Double = 0.0
    ) {
        self.name = name
        self.symbol = symbol
        self.category = category
        self.quantity = quantity
        self.currentValue = currentValue
    }
}

// MARK: - Asset Categories

/// Valid asset category values accepted by the API
enum APIAssetCategory: String, Codable, CaseIterable {
    case crypto
    case stocks
    case cash
    case realEstate
    case retirement
}
