//
//  OfflineSyncManagerTests.swift
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

    func setReachabilityHandler(_ handler: (() -> Void)?) {
        reachabilityHandler = handler
    }

    /// Test helper: updates reachability and invokes the same callback path the real monitor uses.
    func setConnected(_ value: Bool) {
        isConnected = value
        reachabilityHandler?()
    }
}

@Suite("OfflineSyncManager", .serialized)
@MainActor
struct OfflineSyncManagerTests {

    private func makeSUT(
        mock: MockDataService = MockDataService(),
        isOnline: Bool = true
    ) throws -> (OfflineSyncManager, PendingTransactionStore, MockDataService, FakeNetworkMonitor) {
        let container = try OfflinePersistence.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let pendingStore = PendingTransactionStore(modelContext: context)
        let network = FakeNetworkMonitor(isConnected: isOnline)
        let manager = OfflineSyncManager(
            dataService: mock,
            pendingStore: pendingStore,
            network: network,
            beforeSecondAttemptNs: 0,
            beforeThirdAttemptNs: 0
        )
        return (manager, pendingStore, mock, network)
    }

    // MARK: - isAPIErrorRetryableInOfflineSync

    @Test func apiErrorRetryableMap_networkAnd5xx() {
        #expect(isAPIErrorRetryableInOfflineSync(APIError.networkError(URLError(.notConnectedToInternet))) == true)
        #expect(isAPIErrorRetryableInOfflineSync(APIError.serverError(503)) == true)
    }

    @Test func apiErrorRetryableMap_unauthorizedAndValidation() {
        #expect(isAPIErrorRetryableInOfflineSync(APIError.unauthorized) == false)
        #expect(isAPIErrorRetryableInOfflineSync(APIError.notAuthenticated) == false)
        #expect(isAPIErrorRetryableInOfflineSync(APIError.validationError([])) == false)
    }

    // MARK: - FIFO + success

    @Test func syncFIFOOrder() async throws {
        var symbols: [String?] = []
        let mock = MockDataService()
        mock.createSmartTransactionHandler = { req in
            symbols.append(req.symbol)
        }
        let (manager, _, _, _) = try makeSUT(mock: mock, isOnline: true)
        try manager.enqueue(try sampleRequest(symbol: "1"))
        try manager.enqueue(try sampleRequest(symbol: "2"))
        await manager.syncNow()
        #expect(symbols == ["1", "2"])
    }

    // MARK: - Classified retries

    @Test func validationErrorDoesNotRetryThreeTimes() async throws {
        let mock = MockDataService()
        mock.createSmartTransactionError = APIError.validationError(["bad"])
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: true)
        try manager.enqueue(try sampleRequest())
        await manager.syncNow()
        #expect(data.createSmartTransactionCallCount == 1)
        let rows = try store.fetchAllSortedByCreatedAt()
        #expect(rows.count == 1)
        #expect(rows[0].pendingStatus == .failed)
    }

    @Test func serverErrorRetriesUpToThreeTimes() async throws {
        let mock = MockDataService()
        mock.createSmartTransactionError = APIError.serverError(503)
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: true)
        try manager.enqueue(try sampleRequest())
        await manager.syncNow()
        #expect(data.createSmartTransactionCallCount == 3)
        let row = try #require(try store.fetchAllSortedByCreatedAt().first)
        #expect(row.pendingStatus == .failed)
    }

    // MARK: - includeFailed

    @Test func syncWithRetryFailedOffSkipsFailedRows() async throws {
        let mock = MockDataService()
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: true)
        let dataBlob = try JSONEncoder().encode(try sampleRequest())
        _ = try store.insert(requestData: dataBlob, status: .failed)
        await manager.syncNow(retryFailedItems: false)
        #expect(data.createSmartTransactionCallCount == 0)
        #expect(try store.fetchAllSortedByCreatedAt().count == 1)
    }

    @Test func syncWithRetryFailedOnProcessesFailedRow() async throws {
        let mock = MockDataService()
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: true)
        let dataBlob = try JSONEncoder().encode(try sampleRequest())
        _ = try store.insert(requestData: dataBlob, status: .failed)
        await manager.syncNow(retryFailedItems: true)
        #expect(data.createSmartTransactionCallCount == 1)
        #expect(try store.fetchAllSortedByCreatedAt().isEmpty)
    }

    // MARK: - Off while syncing

    @Test func noProgressWhenOffline() async throws {
        let mock = MockDataService()
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: false)
        try manager.enqueue(try sampleRequest())
        await manager.syncNow()
        #expect(data.createSmartTransactionCallCount == 0)
        #expect(try store.fetchAllSortedByCreatedAt().count == 1)
    }

    @Test func whenPathBecomesSatisfiedHandlerDrainsQueue() async throws {
        let mock = MockDataService()
        let (manager, store, data, network) = try makeSUT(mock: mock, isOnline: false)
        try manager.enqueue(try sampleRequest())
        network.setConnected(true)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(
            data.createSmartTransactionCallCount == 1
                && (try? store.fetchAllSortedByCreatedAt().isEmpty) == true
        )
    }

    // MARK: - Decode failure

    @Test func invalidQueuedPayloadIsMarkedFailedWithoutPosting() async throws {
        let mock = MockDataService()
        let (manager, store, data, _) = try makeSUT(mock: mock, isOnline: true)
        _ = try store.insert(requestData: Data("not json".utf8), status: .pending)
        await manager.syncNow()
        #expect(data.createSmartTransactionCallCount == 0)
        let row = try #require(try store.fetchAllSortedByCreatedAt().first)
        #expect(row.pendingStatus == .failed)
    }

    // MARK: - Helpers

    private func sampleRequest(symbol: String = "SYM") throws -> APISmartTransactionCreateRequest {
        let r = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "N",
            symbol: symbol,
            quantity: 1,
            pricePerUnit: 1,
            accountName: "A",
            accountType: "brokerage",
            date: nil
        )
        return r
    }
}
