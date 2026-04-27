//
//  CachedPersonalDashboard.swift
//  VaultTracker
//

import Foundation
import SwiftData

@Model
final class CachedPersonalDashboard {
    @Attribute(.unique) var userId: String
    /// Encoded `APIDashboardResponse`
    var data: Data
    var lastUpdated: Date

    init(userId: String, data: Data, lastUpdated: Date = Date()) {
        self.userId = userId
        self.data = data
        self.lastUpdated = lastUpdated
    }
}
