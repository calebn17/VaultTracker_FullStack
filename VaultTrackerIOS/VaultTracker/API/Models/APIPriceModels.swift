//
//  APIPriceModels.swift
//  VaultTracker
//

import Foundation

/// Result of POST /api/v1/prices/refresh
struct APIPriceRefreshResult: Codable {
    let updated: [APIPriceUpdate]
    let skipped: [String]
    let errors: [APIPriceError]
}

struct APIPriceUpdate: Codable {
    let assetId: String
    let symbol: String?
    let oldValue: Double
    let newValue: Double
    let price: Double

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case symbol
        case oldValue = "old_value"
        case newValue = "new_value"
        case price
    }
}

struct APIPriceError: Codable {
    let symbol: String
    let error: String
}
