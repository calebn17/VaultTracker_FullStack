//
//  APIDashboardResponse.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

/// Response model for GET /api/v1/dashboard
/// Contains aggregated financial data for the home screen
struct APIDashboardResponse: Codable {
    /// Total net worth across all assets
    let totalNetWorth: Double

    /// Breakdown of value by asset category
    let categoryTotals: APICategoryTotals

    /// Assets grouped by category
    /// Keys: "crypto", "stocks", "cash", "realEstate", "retirement"
    let groupedHoldings: [String: [APIGroupedHolding]]
}

/// Category-wise breakdown of asset values
struct APICategoryTotals: Codable, Equatable {
    let crypto: Double
    let stocks: Double
    let cash: Double
    let realEstate: Double
    let retirement: Double

    init(
        crypto: Double = 0.0,
        stocks: Double = 0.0,
        cash: Double = 0.0,
        realEstate: Double = 0.0,
        retirement: Double = 0.0
    ) {
        self.crypto = crypto
        self.stocks = stocks
        self.cash = cash
        self.realEstate = realEstate
        self.retirement = retirement
    }
}

/// Individual asset holding within a category group
struct APIGroupedHolding: Codable, Equatable {
    let id: String
    let name: String
    let symbol: String?
    let quantity: Double
    let currentValue: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case quantity
        case currentValue = "current_value"
    }
}
