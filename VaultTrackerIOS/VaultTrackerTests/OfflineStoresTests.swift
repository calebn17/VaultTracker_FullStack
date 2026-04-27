//
//  OfflineStoresTests.swift
//  VaultTrackerTests
//
//  Single serialized suite: parallel SwiftData in-memory stacks have been unstable in xcodebuild.

import Foundation
import SwiftData
import Testing
@testable import VaultTracker

@Suite("Offline SwiftData stores", .serialized)
@MainActor
struct OfflineStoresTests {

    private func makePendingStore() throws -> (PendingTransactionStore, ModelContainer) {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let store = PendingTransactionStore(modelContext: context)
        return (store, container)
    }

    private func makeCacheStore() throws -> (CachedDataStore, ModelContainer) {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let store = CachedDataStore(modelContext: context)
        return (store, container)
    }

    // MARK: - PendingTransactionStore

    @Test func pendingInsertFetchSortedUpdateDelete() throws {
        let (store, _) = try makePendingStore()

        let reqA = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Acme",
            symbol: "ACM",
            quantity: 1,
            pricePerUnit: 10,
            accountName: "Broker",
            accountType: "brokerage",
            date: nil
        )
        let reqB = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "crypto",
            assetName: "Bitcoin",
            symbol: "BTC",
            quantity: 0.5,
            pricePerUnit: 40_000,
            accountName: "Exchange",
            accountType: "cryptoExchange",
            date: nil
        )
        let dataA = try JSONEncoder().encode(reqA)
        let dataB = try JSONEncoder().encode(reqB)

        let uid = "pending-store-test-user"
        let idA = try store.insert(requestData: dataA, userId: uid)
        let idB = try store.insert(requestData: dataB, userId: uid)

        let rows = try store.fetchAllSortedByCreatedAt()
        #expect(rows.count == 2)
        #expect(rows[0].id == idA)
        #expect(rows[1].id == idB)
        #expect(rows[0].statusRaw == PendingStatus.pending.rawValue)

        try store.updateStatus(id: idA, status: .syncing, retryCount: 1, lastError: nil)
        let fetched = try #require(try store.fetch(id: idA))
        #expect(fetched.statusRaw == PendingStatus.syncing.rawValue)
        #expect(fetched.retryCount == 1)

        try store.delete(id: idB)
        #expect(try store.fetchAllSortedByCreatedAt().count == 1)

        try store.deleteAll()
        #expect(try store.fetchAllSortedByCreatedAt().isEmpty)
    }

    @Test func pendingDeleteAllForUserPreservesOtherUsers() throws {
        let (store, _) = try makePendingStore()
        let data = try JSONEncoder().encode(APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Acme",
            symbol: "ACM",
            quantity: 1,
            pricePerUnit: 10,
            accountName: "Broker",
            accountType: "brokerage",
            date: nil
        ))

        try store.insert(requestData: data, userId: "u1")
        try store.insert(requestData: data, userId: "u2")
        try store.deleteAll(forUserId: "u1")

        #expect(try store.fetchAllSortedByCreatedAt(forUserId: "u1").isEmpty)
        #expect(try store.fetchAllSortedByCreatedAt(forUserId: "u2").count == 1)
    }

    // MARK: - CachedDataStore

    @Test func cachePersonalDashboardRoundTrip() throws {
        let (store, _) = try makeCacheStore()
        let userId = "firebase-user-1"

        let dashboard = APIDashboardResponse(
            totalNetWorth: 99_000,
            categoryTotals: APICategoryTotals(crypto: 1, stocks: 2, cash: 3, realEstate: 4, retirement: 5),
            groupedHoldings: [:]
        )
        let encoded = try JSONEncoder().encode(dashboard)
        try store.upsertPersonalDashboard(userId: userId, data: encoded)

        let cached = try #require(try store.personalDashboard(userId: userId))
        let decoded = try JSONDecoder().decode(APIDashboardResponse.self, from: cached.data)
        #expect(decoded.totalNetWorth == 99_000)
        #expect(decoded.categoryTotals.crypto == 1)

        let updated = APIDashboardResponse(
            totalNetWorth: 100,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        )
        try store.upsertPersonalDashboard(userId: userId, data: try JSONEncoder().encode(updated))
        let cached2 = try #require(try store.personalDashboard(userId: userId))
        let decoded2 = try JSONDecoder().decode(APIDashboardResponse.self, from: cached2.data)
        #expect(decoded2.totalNetWorth == 100)
    }

    @Test func cacheHouseholdDashboardRoundTrip() throws {
        let (store, _) = try makeCacheStore()
        let userId = "firebase-user-1"

        let member = APIHouseholdMemberDashboard(
            userId: "m1",
            email: "a@b.com",
            totalNetWorth: 50,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        )
        let response = APIHouseholdDashboardResponse(
            householdId: "hh-1",
            totalNetWorth: 50,
            categoryTotals: APICategoryTotals(),
            members: [member]
        )
        let encoded = try JSONEncoder().encode(response)
        try store.upsertHouseholdDashboard(userId: userId, data: encoded)

        let cached = try #require(try store.householdDashboard(userId: userId))
        let decoded = try JSONDecoder().decode(APIHouseholdDashboardResponse.self, from: cached.data)
        #expect(decoded.householdId == "hh-1")
        #expect(decoded.members.count == 1)
    }

    @Test func cacheNetWorthHistoryPerScopeAndPeriod() throws {
        let (store, _) = try makeCacheStore()
        let userId = "u1"
        let snapshot = APINetWorthSnapshot(date: Date(timeIntervalSince1970: 1_700_000_000), value: 12)
        let payload = APINetWorthHistoryResponse(snapshots: [snapshot])
        let data = try JSONEncoder().encode(payload)

        try store.upsertNetWorthHistory(userId: userId, scope: .personal, period: .daily, data: data)
        try store.upsertNetWorthHistory(userId: userId, scope: .household, period: .daily, data: data)
        try store.upsertNetWorthHistory(userId: userId, scope: .personal, period: .weekly, data: data)

        let personalDaily = try #require(
            try store.netWorthHistory(userId: userId, scope: .personal, period: .daily)
        )
        let householdDaily = try #require(
            try store.netWorthHistory(userId: userId, scope: .household, period: .daily)
        )
        let personalWeekly = try #require(
            try store.netWorthHistory(userId: userId, scope: .personal, period: .weekly)
        )

        let roundTrip = try JSONDecoder().decode(APINetWorthHistoryResponse.self, from: personalDaily.data)
        #expect(roundTrip.snapshots.count == 1)
        #expect(personalDaily.cacheKey != householdDaily.cacheKey)
        #expect(personalDaily.cacheKey != personalWeekly.cacheKey)
    }

    @Test func cacheTransactionsUpsertAndReplaceAll() throws {
        let (store, _) = try makeCacheStore()
        let userId = "u1"
        let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

        func enriched(id: String) -> APIEnrichedTransactionResponse {
            APIEnrichedTransactionResponse(
                id: id,
                userId: userId,
                assetId: "asset-1",
                accountId: "acct-1",
                transactionType: "buy",
                quantity: 1,
                pricePerUnit: 2,
                totalValue: 2,
                date: sampleDate,
                asset: APIAssetSummary(id: "asset-1", name: "A", symbol: "A", category: "stocks"),
                account: APIAccountSummary(id: "acct-1", name: "B", accountType: "brokerage")
            )
        }

        let firstRow = enriched(id: "t1")
        let secondRow = enriched(id: "t2")
        try store.upsertTransaction(
            userId: userId,
            transactionId: firstRow.id,
            data: try JSONEncoder().encode(firstRow)
        )
        try store.upsertTransaction(
            userId: userId,
            transactionId: secondRow.id,
            data: try JSONEncoder().encode(secondRow)
        )
        #expect(try store.transactions(for: userId).count == 2)

        let thirdRow = enriched(id: "t3")
        let thirdData = try JSONEncoder().encode(thirdRow)
        try store.replaceAllTransactions(for: userId, rows: [(transactionId: thirdRow.id, data: thirdData)])
        let rows = try store.transactions(for: userId)
        #expect(rows.count == 1)
        let decoded = try JSONDecoder().decode(APIEnrichedTransactionResponse.self, from: rows[0].data)
        #expect(decoded.id == "t3")
    }

    @Test func cacheClearAllCaches() throws {
        let (store, _) = try makeCacheStore()
        let userId = "u1"
        let dash = APIDashboardResponse(
            totalNetWorth: 1,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        )
        try store.upsertPersonalDashboard(userId: userId, data: try JSONEncoder().encode(dash))
        try store.clearAllCaches()
        #expect(try store.personalDashboard(userId: userId) == nil)
    }

    @Test func cacheClearAllCachesForUserPreservesOtherUsers() throws {
        let (store, _) = try makeCacheStore()
        let dash = APIDashboardResponse(
            totalNetWorth: 1,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        )
        let data = try JSONEncoder().encode(dash)

        try store.upsertPersonalDashboard(userId: "u1", data: data)
        try store.upsertHouseholdDashboard(userId: "u1", data: data)
        try store.upsertNetWorthHistory(userId: "u1", scope: .personal, period: .daily, data: data)
        try store.upsertTransaction(userId: "u1", transactionId: "t1", data: data)
        try store.upsertPersonalDashboard(userId: "u2", data: data)

        try store.clearAllCaches(for: "u1")

        #expect(try store.personalDashboard(userId: "u1") == nil)
        #expect(try store.householdDashboard(userId: "u1") == nil)
        #expect(try store.netWorthHistory(userId: "u1", scope: .personal, period: .daily) == nil)
        #expect(try store.transactions(for: "u1").isEmpty)
        #expect(try store.personalDashboard(userId: "u2") != nil)
    }
}
