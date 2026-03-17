//
//  AssetMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

// Converts APIAssetResponse values into domain Asset models.
// Cash and realEstate assets have no ticker symbol in the API; the asset name is
// substituted to satisfy the non-optional `symbol` field on the domain model.
// A synthetic `purchasePrice` is derived as `currentValue / quantity` because the
// legacy domain model requires it — this approximation will be removed when the
// domain model is simplified in a future phase.

import Foundation

enum AssetMapper {

    /// Convert an API asset response to the app's domain Asset model.
    ///
    /// **symbol:** Optional in the API (cash/real-estate have no ticker).
    /// Falls back to the asset name so the existing model's non-optional
    /// `symbol: String` is always populated.
    ///
    /// **price:** The current domain model stores a `price` (purchase price
    /// per unit) but the API only returns `currentValue` and `quantity`.
    /// We derive an approximate price as `currentValue / quantity` where
    /// quantity > 0; otherwise 0. This field will be removed in Phase 4
    /// when the domain model is simplified.
    @MainActor
    static func toDomain(_ response: APIAssetResponse) -> Asset {
        let approximatePrice = response.quantity > 0
            ? response.currentValue / response.quantity
            : 0.0

        return Asset(
            id: UUID(uuidString: response.id) ?? UUID(),
            name: response.name,
            category: mapCategory(response.category),
            symbol: response.symbol ?? response.name,
            quantity: response.quantity,
            purchasePrice: approximatePrice,
            currentValue: response.currentValue,
            lastUpdated: response.lastUpdated
        )
    }

    /// Convert an array of API asset responses to domain models.
    @MainActor
    static func toDomain(_ responses: [APIAssetResponse]) -> [Asset] {
        responses.map { toDomain($0) }
    }

    // MARK: - Private

    static func mapCategory(_ raw: String) -> AssetCategory {
        switch raw {
        case "crypto":       return .crypto
        case "stocks":       return .stocks
        case "cash":         return .cash
        case "real_estate", "realEstate": return .realEstate
        case "retirement":   return .retirement
        default:             return .cash
        }
    }
}
