//
//  DataRepositoryTests.swift
//  VaultTrackerTests
//

import Foundation
import SwiftData
import Testing
@testable import VaultTracker

@MainActor
private final class FakeNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool
    private var reachabilityHandler: (() -> Void)?

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }

    func setReachabilityHandler(_ handler: (() -> Void)?) { reachabilityHandler = handler }
}

@Suite("DataRepository", .serialized)
@MainActor
struct DataRepositoryTests {

    private static let testUser = "user-repo-test"
    private static let tDate = Date(timeIntervalSince1970: 1_000_000)

    private func makeSUT(
        online: Bool = true
    ) throws -> (
        repo: DataRepository, cache: CachedDataStore, data: MockDataService, api: MockAPIService, pending: PendingTransactionStore, network: FakeNetworkMonitor
    ) {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let pending = PendingTransactionStore(modelContext: context)
        let cache = CachedDataStore(modelContext: context)
        let data = MockDataService()
        let api = MockAPIService()
        let network = FakeNetworkMonitor(isConnected: online)
        let sync = OfflineSyncManager(
            dataService: data,
            pendingStore: pending,
            network: network,
            currentUserId: { Self.testUser },
            beforeSecondAttemptNs: 0,
            beforeThirdAttemptNs: 0
        )
        let repo = DataRepository(
            dataService: data,
            api: api,
            network: network,
            cache: cache,
            syncManager: sync,
            currentUserId: { Self.testUser }
        )
        return (repo, cache, data, api, pending, network)
    }

    @Test func createWhenOnlineCallsDataService() async throws {
        let (repo, _, data, _, pending, _) = try makeSUT(online: true)
        let req = Self.sampleSmartRequest()
        try await repo.createTransaction(req)
        #expect(data.createSmartTransactionCallCount == 1)
        #expect(try pending.fetchAllSortedByCreatedAt().isEmpty)
    }

    @Test func createWhenOfflineEnqueues() async throws {
        let (repo, _, data, _, pending, _) = try makeSUT(online: false)
        let req = Self.sampleSmartRequest()
        try await repo.createTransaction(req)
        #expect(data.createSmartTransactionCallCount == 0)
        let rows = try pending.fetchAllSortedByCreatedAt(forUserId: Self.testUser)
        #expect(rows.count == 1)
        #expect(rows[0].userId == Self.testUser)
    }

    @Test func createWhenOnlineTransportFailsEnqueues() async throws {
        let (repo, _, data, _, pending, _) = try makeSUT(online: true)
        data.createSmartTransactionError = APIError.networkError(Self.sampleURLError())
        let req = Self.sampleSmartRequest()
        try await repo.createTransaction(req)
        #expect(data.createSmartTransactionCallCount == 1)
        let rows = try pending.fetchAllSortedByCreatedAt(forUserId: Self.testUser)
        #expect(rows.count == 1)
        #expect(rows[0].userId == Self.testUser)
    }

    @Test func createWhenOnlineValidationFailsDoesNotEnqueue() async throws {
        let (repo, _, data, _, pending, _) = try makeSUT(online: true)
        data.createSmartTransactionError = APIError.validationError(["assetName is required"])
        await #expect(throws: APIError.self) {
            try await repo.createTransaction(Self.sampleSmartRequest())
        }
        #expect(data.createSmartTransactionCallCount == 1)
        #expect(try pending.fetchAllSortedByCreatedAt(forUserId: Self.testUser).isEmpty)
    }

    @Test func createWhenOfflineWithoutUserThrows() async throws {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let pending = PendingTransactionStore(modelContext: context)
        let cache = CachedDataStore(modelContext: context)
        let data = MockDataService()
        let api = MockAPIService()
        let network = FakeNetworkMonitor(isConnected: false)
        let sync = OfflineSyncManager(
            dataService: data,
            pendingStore: pending,
            network: network,
            currentUserId: { nil },
            beforeSecondAttemptNs: 0,
            beforeThirdAttemptNs: 0
        )
        let repo = DataRepository(
            dataService: data,
            api: api,
            network: network,
            cache: cache,
            syncManager: sync,
            currentUserId: { nil }
        )
        await #expect(throws: OfflineError.self) {
            try await repo.createTransaction(Self.sampleSmartRequest())
        }
        #expect(try pending.fetchAllSortedByCreatedAt().isEmpty)
    }

    @Test func fetchPersonalDashboardSucceedsAndCaches() async throws {
        let (repo, cache, data, _, _, _) = try makeSUT(online: true)
        let d = try await repo.fetchPersonalDashboard()
        #expect(d.isStale == false)
        #expect(d.0.totalNetWorth == data.dashboardStub.totalNetWorth)
        let row = try #require(try cache.personalDashboard(userId: Self.testUser))
        let decoded = try JSONDecoder().decode(APIDashboardResponse.self, from: row.data)
        #expect(decoded.totalNetWorth == d.0.totalNetWorth)
    }

    @Test func fetchPersonalDashboardFallsBackToCacheWithStale() async throws {
        let (repo, cache, data, _, _, _) = try makeSUT(online: true)
        // Seed cache
        _ = try await repo.fetchPersonalDashboard()
        #expect(try #require(try cache.personalDashboard(userId: Self.testUser)) != nil)
        data.dashboardError = APIError.serverError(503)
        let d = try await repo.fetchPersonalDashboard()
        #expect(d.isStale == true)
        #expect(d.0.totalNetWorth == data.dashboardStub.totalNetWorth)
    }

    @Test func fetchPersonalDashboardAuthErrorDoesNotFallbackToCache() async throws {
        let (repo, _, data, _, _, _) = try makeSUT(online: true)
        _ = try await repo.fetchPersonalDashboard()
        data.dashboardError = APIError.unauthorized
        await #expect(throws: APIError.self) {
            _ = try await repo.fetchPersonalDashboard()
        }
    }

    @Test func fetchPersonalDashboardOfflineServesCache() async throws {
        let (repo, _, data, _, _, network) = try makeSUT(online: true)
        _ = try await repo.fetchPersonalDashboard()
        network.isConnected = false
        let c = try await repo.fetchPersonalDashboard()
        #expect(c.isStale == true)
        #expect(c.0.totalNetWorth == data.dashboardStub.totalNetWorth)
    }

    @Test func fetchTransactionsReplacesCacheAndIsFresh() async throws {
        let (repo, cache, _, api, _, _) = try makeSUT(online: true)
        let enriched = [Self.minimalEnriched(id: "tx-1")]
        api.fetchTransactionsResult = enriched
        let out = try await repo.fetchTransactions()
        #expect(out.isStale == false)
        #expect(out.0.count == 1)
        let rows = try cache.transactions(for: Self.testUser)
        #expect(rows.count == 1)
        #expect(rows[0].transactionId == "tx-1")
    }

    @Test func fetchTransactionsAuthErrorDoesNotFallbackToCache() async throws {
        let (repo, _, _, api, _, _) = try makeSUT(online: true)
        api.fetchTransactionsResult = [Self.minimalEnriched(id: "tx-1")]
        _ = try await repo.fetchTransactions()
        api.fetchTransactionsError = APIError.forbidden
        await #expect(throws: APIError.self) {
            _ = try await repo.fetchTransactions()
        }
    }

    @Test func fetchNetWorthHistoryCachesAPILayer() async throws {
        let (repo, cache, _, api, _, _) = try makeSUT(online: true)
        api.fetchNetWorthHistoryResult = APINetWorthHistoryResponse(
            snapshots: [APINetWorthSnapshot(date: Self.tDate, value: 42)]
        )
        let out = try await repo.fetchPersonalNetWorthHistory(period: .monthly)
        #expect(out.isStale == false)
        #expect(out.0.count == 1)
        #expect(out.0[0].value == 42)
        #expect(api.lastNetWorthHistoryPeriod == .monthly)
        let row = try #require(try cache.netWorthHistory(
            userId: Self.testUser, scope: .personal, period: .monthly
        ))
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(APINetWorthHistoryResponse.self, from: row.data)
        #expect(decoded.snapshots.count == 1)
    }

    @Test func fetchWithNoUserIdThrows() async throws {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let pending = PendingTransactionStore(modelContext: context)
        let cache = CachedDataStore(modelContext: context)
        let data = MockDataService()
        let api = MockAPIService()
        let network = FakeNetworkMonitor(isConnected: true)
        let sync = OfflineSyncManager(
            dataService: data,
            pendingStore: pending,
            network: network,
            currentUserId: { nil },
            beforeSecondAttemptNs: 0,
            beforeThirdAttemptNs: 0
        )
        let repo = DataRepository(
            dataService: data,
            api: api,
            network: network,
            cache: cache,
            syncManager: sync,
            currentUserId: { nil }
        )
        await #expect(throws: OfflineError.self) {
            _ = try await repo.fetchPersonalDashboard()
        }
    }

    @Test func clearLocalDataClearsCurrentUserCacheAndPendingRows() async throws {
        let (repo, cache, _, _, pending, _) = try makeSUT(online: false)
        let request = Self.sampleSmartRequest()
        let encodedDashboard = try JSONEncoder().encode(APIDashboardResponse(
            totalNetWorth: 99,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        ))
        try cache.upsertPersonalDashboard(userId: Self.testUser, data: encodedDashboard)
        try cache.upsertPersonalDashboard(userId: "other-user", data: encodedDashboard)
        try pending.insert(requestData: try JSONEncoder().encode(request), userId: Self.testUser)
        try pending.insert(requestData: try JSONEncoder().encode(request), userId: "other-user")

        try repo.clearLocalData()

        #expect(try cache.personalDashboard(userId: Self.testUser) == nil)
        #expect(try pending.fetchAllSortedByCreatedAt(forUserId: Self.testUser).isEmpty)
        #expect(try cache.personalDashboard(userId: "other-user") != nil)
        #expect(try pending.fetchAllSortedByCreatedAt(forUserId: "other-user").count == 1)
    }

    // MARK: - Helpers

    private static func sampleSmartRequest() -> APISmartTransactionCreateRequest {
        APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "A",
            symbol: "A",
            quantity: 1,
            pricePerUnit: 1,
            accountName: "A",
            accountType: "brokerage",
            date: nil
        )
    }

    private static func sampleURLError() -> URLError {
        URLError(.notConnectedToInternet)
    }

    private static func minimalEnriched(id: String) -> APIEnrichedTransactionResponse {
        let asset = APIAssetSummary(
            id: "as1",
            name: "A",
            symbol: "A",
            category: "stocks"
        )
        let account = APIAccountSummary(
            id: "ac1",
            name: "Acc",
            accountType: "brokerage"
        )
        return APIEnrichedTransactionResponse(
            id: id,
            userId: testUser,
            assetId: "as1",
            accountId: "ac1",
            transactionType: "buy",
            quantity: 1,
            pricePerUnit: 1,
            totalValue: 1,
            date: tDate,
            asset: asset,
            account: account
        )
    }
}
