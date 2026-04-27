//
//  PendingTransactionStore.swift
//  VaultTracker
//

import Foundation
import SwiftData

/// SwiftData access for queued smart-transaction payloads.
@MainActor
final class PendingTransactionStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a new pending row and returns its id.
    func insert(requestData: Data, userId: String, status: PendingStatus = .pending) throws -> UUID {
        let row = PendingTransaction(userId: userId, request: requestData, status: status)
        modelContext.insert(row)
        try modelContext.save()
        return row.id
    }

    func fetchAllSortedByCreatedAt(forUserId userId: String) throws -> [PendingTransaction] {
        let sort = SortDescriptor(\PendingTransaction.createdAt, order: .forward)
        let predicate = #Predicate<PendingTransaction> { $0.userId == userId }
        let descriptor = FetchDescriptor<PendingTransaction>(predicate: predicate, sortBy: [sort])
        return try modelContext.fetch(descriptor)
    }

    func fetchAllSortedByCreatedAt() throws -> [PendingTransaction] {
        let sort = SortDescriptor(\PendingTransaction.createdAt, order: .forward)
        let descriptor = FetchDescriptor<PendingTransaction>(sortBy: [sort])
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> PendingTransaction? {
        let predicate = #Predicate<PendingTransaction> { $0.id == id }
        var descriptor = FetchDescriptor<PendingTransaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func updateStatus(id: UUID, status: PendingStatus, retryCount: Int? = nil, lastError: String?) throws {
        guard let row = try fetch(id: id) else { return }
        row.statusRaw = status.rawValue
        if let retryCount { row.retryCount = retryCount }
        row.lastError = lastError
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        guard let row = try fetch(id: id) else { return }
        modelContext.delete(row)
        try modelContext.save()
    }

    func deleteAll() throws {
        let all = try fetchAllSortedByCreatedAt()
        for row in all {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    func deleteAll(forUserId userId: String) throws {
        let rows = try fetchAllSortedByCreatedAt(forUserId: userId)
        for row in rows {
            modelContext.delete(row)
        }
        try modelContext.save()
    }
}
