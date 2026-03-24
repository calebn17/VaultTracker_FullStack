//
//  APINetWorthHistoryResponse.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

/// Response model for GET /api/v1/networth/history
/// Contains historical net worth snapshots for charting
struct APINetWorthHistoryResponse: Codable {
    let snapshots: [APINetWorthSnapshot]
}

/// Individual net worth snapshot at a point in time
struct APINetWorthSnapshot: Codable {
    let date: Date
    let value: Double
}

// MARK: - Query Parameters

/// Valid period values for the history endpoint query parameter
/// Usage: GET /api/v1/networth/history?period=daily
enum APINetWorthPeriod: String, CaseIterable {
    case daily
    case weekly
    case monthly
}
