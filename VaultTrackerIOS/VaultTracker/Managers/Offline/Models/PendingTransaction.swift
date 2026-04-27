//
//  PendingTransaction.swift
//  VaultTracker
//

import Foundation
import SwiftData

enum PendingStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case syncing
    case failed
}

@Model
final class PendingTransaction {
    @Attribute(.unique) var id: UUID
    /// Firebase Auth uid for the account that queued this write; must match the active session to sync.
    /// Default empty supports store migration; rows with no uid are never synced.
    var userId: String = ""
    /// Encoded `APISmartTransactionCreateRequest`
    var request: Data
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    /// `PendingStatus.rawValue`
    var statusRaw: String

    init(
        id: UUID = UUID(),
        userId: String,
        request: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        status: PendingStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.request = request
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.statusRaw = status.rawValue
    }

    /// Parsed `statusRaw`; invalid values are treated as `.pending` for forward compatibility.
    var pendingStatus: PendingStatus { PendingStatus(rawValue: statusRaw) ?? .pending }
}
