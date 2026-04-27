//
//  OfflineCacheKey.swift
//  VaultTracker
//

import Foundation

/// Stable cache keys for SwiftData rows (kept outside `@Model` types for SwiftData macro safety).
enum OfflineCacheKey {
    static func netWorthHistory(userId: String, scope: CachedNetWorthScope, period: APINetWorthPeriod) -> String {
        "\(userId)|\(scope.rawValue)|\(period.rawValue)"
    }

    static func transaction(userId: String, transactionId: String) -> String {
        "\(userId)|\(transactionId)"
    }
}
