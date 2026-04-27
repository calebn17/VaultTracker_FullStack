//
//  CachedNetWorthHistory.swift
//  VaultTracker
//

import Foundation
import SwiftData

/// Scope for net worth history rows (`personal` vs `household`).
enum CachedNetWorthScope: String, CaseIterable, Sendable {
    case personal
    case household
}

@Model
final class CachedNetWorthHistory {
    /// Stable key, e.g. `"\(userId)|personal|daily"`
    @Attribute(.unique) var cacheKey: String
    var userId: String
    /// `CachedNetWorthScope.rawValue`
    var scopeRaw: String
    /// `APINetWorthPeriod.rawValue`
    var periodRaw: String
    /// Encoded `APINetWorthHistoryResponse`
    var data: Data
    var lastUpdated: Date

    init(
        cacheKey: String,
        userId: String,
        scope: CachedNetWorthScope,
        periodRaw: String,
        data: Data,
        lastUpdated: Date = Date()
    ) {
        self.cacheKey = cacheKey
        self.userId = userId
        self.scopeRaw = scope.rawValue
        self.periodRaw = periodRaw
        self.data = data
        self.lastUpdated = lastUpdated
    }
}
