//
//  APIAnalyticsModels.swift
//  VaultTracker
//

import Foundation

/// One category bucket in the analytics allocation map.
struct APIAllocationEntry: Codable {
    let value: Double
    let percentage: Double
}

/// Gain/loss summary from the analytics endpoint (Pydantic uses camelCase JSON keys).
struct APIPerformanceBlock: Codable {
    let totalGainLoss: Double
    let totalGainLossPercent: Double
    let costBasis: Double
    let currentValue: Double
}

/// GET /api/v1/analytics
struct APIAnalyticsResponse: Codable {
    let allocation: [String: APIAllocationEntry]
    let performance: APIPerformanceBlock
}
