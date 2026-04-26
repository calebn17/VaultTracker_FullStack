//
//  CachedTransaction.swift
//  VaultTracker
//

import Foundation
import SwiftData

@Model
final class CachedTransaction {
    /// Stable key, e.g. `"\(userId)|\(transactionId)"`
    @Attribute(.unique) var cacheKey: String
    var userId: String
    var transactionId: String
    /// Encoded `APIEnrichedTransactionResponse`
    var data: Data
    var lastUpdated: Date

    init(
        userId: String,
        transactionId: String,
        data: Data,
        lastUpdated: Date = Date()
    ) {
        self.cacheKey = OfflineCacheKey.transaction(userId: userId, transactionId: transactionId)
        self.userId = userId
        self.transactionId = transactionId
        self.data = data
        self.lastUpdated = lastUpdated
    }
}
