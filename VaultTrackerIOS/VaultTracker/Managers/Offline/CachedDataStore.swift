//
//  CachedDataStore.swift
//  VaultTracker
//

import Foundation
import SwiftData

/// SwiftData access for read-through caches (dashboards, transactions, net worth history).
@MainActor
final class CachedDataStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Personal dashboard

    func upsertPersonalDashboard(userId: String, data: Data, lastUpdated: Date = Date()) throws {
        if let existing = try fetchPersonalDashboardModel(userId: userId) {
            existing.data = data
            existing.lastUpdated = lastUpdated
        } else {
            modelContext.insert(CachedPersonalDashboard(userId: userId, data: data, lastUpdated: lastUpdated))
        }
        try modelContext.save()
    }

    func personalDashboard(userId: String) throws -> CachedPersonalDashboard? {
        try fetchPersonalDashboardModel(userId: userId)
    }

    private func fetchPersonalDashboardModel(userId: String) throws -> CachedPersonalDashboard? {
        let predicate = #Predicate<CachedPersonalDashboard> { $0.userId == userId }
        var descriptor = FetchDescriptor<CachedPersonalDashboard>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Household dashboard

    func upsertHouseholdDashboard(userId: String, data: Data, lastUpdated: Date = Date()) throws {
        if let existing = try fetchHouseholdDashboardModel(userId: userId) {
            existing.data = data
            existing.lastUpdated = lastUpdated
        } else {
            modelContext.insert(CachedHouseholdDashboard(userId: userId, data: data, lastUpdated: lastUpdated))
        }
        try modelContext.save()
    }

    func householdDashboard(userId: String) throws -> CachedHouseholdDashboard? {
        try fetchHouseholdDashboardModel(userId: userId)
    }

    private func fetchHouseholdDashboardModel(userId: String) throws -> CachedHouseholdDashboard? {
        let predicate = #Predicate<CachedHouseholdDashboard> { $0.userId == userId }
        var descriptor = FetchDescriptor<CachedHouseholdDashboard>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Net worth history

    func upsertNetWorthHistory(
        userId: String,
        scope: CachedNetWorthScope,
        period: APINetWorthPeriod,
        data: Data,
        lastUpdated: Date = Date()
    ) throws {
        let cacheKey = OfflineCacheKey.netWorthHistory(userId: userId, scope: scope, period: period)
        if let existing = try fetchNetWorthHistoryModel(cacheKey: cacheKey) {
            existing.data = data
            existing.lastUpdated = lastUpdated
        } else {
            modelContext.insert(
                CachedNetWorthHistory(
                    cacheKey: cacheKey,
                    userId: userId,
                    scope: scope,
                    periodRaw: period.rawValue,
                    data: data,
                    lastUpdated: lastUpdated
                )
            )
        }
        try modelContext.save()
    }

    func netWorthHistory(
        userId: String,
        scope: CachedNetWorthScope,
        period: APINetWorthPeriod
    ) throws -> CachedNetWorthHistory? {
        let cacheKey = OfflineCacheKey.netWorthHistory(userId: userId, scope: scope, period: period)
        return try fetchNetWorthHistoryModel(cacheKey: cacheKey)
    }

    private func fetchNetWorthHistoryModel(cacheKey: String) throws -> CachedNetWorthHistory? {
        let predicate = #Predicate<CachedNetWorthHistory> { $0.cacheKey == cacheKey }
        var descriptor = FetchDescriptor<CachedNetWorthHistory>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Transactions

    func upsertTransaction(userId: String, transactionId: String, data: Data, lastUpdated: Date = Date()) throws {
        let cacheKey = OfflineCacheKey.transaction(userId: userId, transactionId: transactionId)
        if let existing = try fetchTransactionModel(cacheKey: cacheKey) {
            existing.data = data
            existing.lastUpdated = lastUpdated
        } else {
            modelContext.insert(
                CachedTransaction(userId: userId, transactionId: transactionId, data: data, lastUpdated: lastUpdated)
            )
        }
        try modelContext.save()
    }

    func transactions(for userId: String) throws -> [CachedTransaction] {
        let predicate = #Predicate<CachedTransaction> { $0.userId == userId }
        let sort = SortDescriptor(\CachedTransaction.lastUpdated, order: .reverse)
        let descriptor = FetchDescriptor<CachedTransaction>(predicate: predicate, sortBy: [sort])
        return try modelContext.fetch(descriptor)
    }

    func replaceAllTransactions(for userId: String, rows: [(transactionId: String, data: Data)]) throws {
        let existing = try transactions(for: userId)
        for row in existing {
            modelContext.delete(row)
        }
        let now = Date()
        for row in rows {
            modelContext.insert(
                CachedTransaction(userId: userId, transactionId: row.transactionId, data: row.data, lastUpdated: now)
            )
        }
        try modelContext.save()
    }

    private func fetchTransactionModel(cacheKey: String) throws -> CachedTransaction? {
        let predicate = #Predicate<CachedTransaction> { $0.cacheKey == cacheKey }
        var descriptor = FetchDescriptor<CachedTransaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Tests / account switch

    func clearAllCaches() throws {
        try modelContext.fetch(FetchDescriptor<CachedPersonalDashboard>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<CachedHouseholdDashboard>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<CachedNetWorthHistory>()).forEach { modelContext.delete($0) }
        try modelContext.fetch(FetchDescriptor<CachedTransaction>()).forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    func clearAllCaches(for userId: String) throws {
        let personalPredicate = #Predicate<CachedPersonalDashboard> { $0.userId == userId }
        try modelContext.fetch(FetchDescriptor<CachedPersonalDashboard>(predicate: personalPredicate))
            .forEach { modelContext.delete($0) }

        let householdPredicate = #Predicate<CachedHouseholdDashboard> { $0.userId == userId }
        try modelContext.fetch(FetchDescriptor<CachedHouseholdDashboard>(predicate: householdPredicate))
            .forEach { modelContext.delete($0) }

        let historyPredicate = #Predicate<CachedNetWorthHistory> { $0.userId == userId }
        try modelContext.fetch(FetchDescriptor<CachedNetWorthHistory>(predicate: historyPredicate))
            .forEach { modelContext.delete($0) }

        let transactionPredicate = #Predicate<CachedTransaction> { $0.userId == userId }
        try modelContext.fetch(FetchDescriptor<CachedTransaction>(predicate: transactionPredicate))
            .forEach { modelContext.delete($0) }

        try modelContext.save()
    }
}
