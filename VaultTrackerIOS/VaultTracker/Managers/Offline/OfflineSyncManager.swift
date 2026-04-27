//
//  OfflineSyncManager.swift
//  VaultTracker
//

import Combine
import Foundation
import os.log

// MARK: - API error classification (sync / retry policy)

/// `true` = transport- or server-class: bounded backoff retries are appropriate.
func isAPIErrorRetryableInOfflineSync(_ error: Error) -> Bool {
    guard let err = error as? APIError else { return true }
    switch err {
    case .networkError:
        return true
    case .serverError:
        return true
    case .notAuthenticated, .unauthorized, .forbidden, .notFound, .validationError, .decodingError:
        return false
    case .unknown(let code):
        if (500 ..< 600).contains(code) { return true }
        if (400 ..< 500).contains(code) { return false }
        return false
    }
}

// MARK: - OfflineSyncManager

/// FIFO smart-transaction sync with **single-flight** passes and **classified** retries
/// (see `Sync contract` in the offline support design). Uses `DataService.createSmartTransaction`
/// so Firebase / auth stay on the same path as online saves.
@MainActor
final class OfflineSyncManager: ObservableObject {
    private static let log = Logger(subsystem: "com.vaulttracker", category: "OfflineSync")

    struct FailedPendingItem: Identifiable, Equatable {
        let id: UUID
        let title: String
        let detail: String?
    }

    enum SyncStatus: Equatable {
        case idle
        case syncing(progress: Int, total: Int)
        case failed(unsyncedCount: Int)
    }

    @Published private(set) var syncStatus: SyncStatus = .idle
    /// Queue depth that still needs a successful server write (`pending` + in-flight `syncing`).
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var failedCount: Int = 0
    @Published private(set) var failedItems: [FailedPendingItem] = []

    private let dataService: DataServiceProtocol
    private let pendingStore: PendingTransactionStore
    private let network: NetworkMonitoring
    private let currentUserId: () -> String?
    private let beforeSecondAttemptNs: UInt64
    private let beforeThirdAttemptNs: UInt64
    private let requestDecoder: JSONDecoder

    private var activeSync: Task<Void, Never>?

    /// - Parameters:
    ///   - beforeSecondAttemptNs: Backoff (nanoseconds) before the second POST. Default 2s. Tests can pass 0.
    ///   - beforeThirdAttemptNs: Backoff before the third POST. Default 4s. Tests can pass 0.
    init(
        dataService: DataServiceProtocol,
        pendingStore: PendingTransactionStore,
        network: NetworkMonitoring,
        currentUserId: @escaping () -> String?,
        beforeSecondAttemptNs: UInt64 = 2_000_000_000,
        beforeThirdAttemptNs: UInt64 = 4_000_000_000
    ) {
        self.dataService = dataService
        self.pendingStore = pendingStore
        self.network = network
        self.currentUserId = currentUserId
        self.beforeSecondAttemptNs = beforeSecondAttemptNs
        self.beforeThirdAttemptNs = beforeThirdAttemptNs
        self.requestDecoder = JSONDecoder()
        self.network.setReachabilityHandler { [weak self] in
            Task { @MainActor in
                guard let self, self.network.isConnected else { return }
                // Auto-drain pending only. Terminal `failed` rows need manual sync / banner
                // (`includeFailed: true`) per sync contract.
                await self.syncNow(retryFailedItems: false)
            }
        }
        Task { await self.refreshQueueMetrics() }
    }

    // MARK: - Public API

    /// Encodes and appends a smart-transaction to the outbox; refresh metrics. Call when offline
    /// (or when the repository decides not to post immediately). Does **not** start a network sync.
    func enqueue(_ request: APISmartTransactionCreateRequest, userId: String) throws {
        let data = try JSONEncoder().encode(request)
        _ = try pendingStore.insert(requestData: data, userId: userId, status: .pending)
        Task { await refreshQueueMetrics() }
    }

    /// Process the queue (FIFO) while `network.isConnected` is `true`. **Single-flight**:
    /// concurrent calls await the in-progress pass and return without starting a second pass.
    /// - Parameter retryFailedItems: When `true`, `failed` rows are retried. When `false` (e.g. auto
    ///   sync on reachability), only `pending` (and any stuck `syncing` reset) are processed.
    func syncNow(retryFailedItems: Bool = true) async {
        if let existingSync = activeSync { await existingSync.value; return }
        let task = Task { @MainActor in
            await self.runSyncPass(retryFailedItems: retryFailedItems)
        }
        activeSync = task
        await task.value
        activeSync = nil
    }

    /// Removes a single queued item by id.
    func discardPending(id: UUID) throws {
        guard let uid = currentUserId() else { return }
        guard let row = try pendingStore.fetch(id: id), row.userId == uid else { return }
        try pendingStore.delete(id: id)
        Task { await refreshQueueMetrics() }
    }

    func clearPendingForCurrentUser() throws {
        guard let uid = currentUserId() else { return }
        try pendingStore.deleteAll(forUserId: uid)
        Task { await refreshQueueMetrics() }
    }

    // MARK: - Internals

    private func runSyncPass(retryFailedItems: Bool) async {
        syncStatus = .idle

        do {
            try await resetStuckSyncingToPending()
        } catch {
            Self.log.error("resetStuckSyncing failed: \(error.localizedDescription, privacy: .public)")
        }

        guard network.isConnected else {
            await refreshQueueMetrics()
            return
        }

        let total: Int
        let workItems: [PendingTransaction]
        do {
            (total, workItems) = try selectWork(includeFailed: retryFailedItems)
        } catch {
            Self.log.error("selectWork: \(error.localizedDescription, privacy: .public)")
            await refreshQueueMetrics()
            return
        }
        // One batch per `syncNow` call. (A `while` loop would re-fetch `failed` rows and spin forever
        // when a row stays terminal after a retry attempt.)
        for (index, row) in workItems.enumerated() {
            syncStatus = .syncing(progress: index, total: total)
            if !network.isConnected { break }
            do {
                try await processOne(row: row)
            } catch {
                Self.log.error("processOne: \(error.localizedDescription, privacy: .public)")
            }
        }

        await refreshQueueMetrics()
    }

    /// Returns `(displayTotal, list)` where `displayTotal` is the count of in-scope rows (for
    /// progress) and `list` is the work batch (subset that is still pending/failed in order).
    private func selectWork(includeFailed: Bool) throws -> (Int, [PendingTransaction]) {
        guard let uid = currentUserId() else { return (0, []) }
        let rows = try pendingStore.fetchAllSortedByCreatedAt(forUserId: uid)
        let inScope: [PendingTransaction] = rows.filter { row in
            switch row.pendingStatus {
            case .pending, .syncing: return true
            case .failed: return includeFailed
            }
        }
        if inScope.isEmpty { return (0, []) }
        return (inScope.count, inScope)
    }

    private func resetStuckSyncingToPending() throws {
        guard let uid = currentUserId() else { return }
        let rows = try pendingStore.fetchAllSortedByCreatedAt(forUserId: uid)
        for row in rows where row.pendingStatus == .syncing {
            try pendingStore.updateStatus(
                id: row.id, status: .pending, retryCount: row.retryCount, lastError: row.lastError
            )
        }
    }

    private func processOne(row: PendingTransaction) async throws {
        let id = row.id
        do {
            let body = try requestDecoder.decode(APISmartTransactionCreateRequest.self, from: row.request)
            try pendingStore.updateStatus(
                id: id, status: .syncing, retryCount: row.retryCount, lastError: nil
            )
            for attempt in 0 ..< 3 {
                if attempt == 1, beforeSecondAttemptNs > 0 {
                    try await Task.sleep(nanoseconds: beforeSecondAttemptNs)
                }
                if attempt == 2, beforeThirdAttemptNs > 0 {
                    try await Task.sleep(nanoseconds: beforeThirdAttemptNs)
                }
                if !network.isConnected { return }
                do {
                    try await dataService.createSmartTransaction(body)
                    try pendingStore.delete(id: id)
                    return
                } catch {
                    if isAPIErrorRetryableInOfflineSync(error), attempt < 2 {
                        try? pendingStore.updateStatus(
                            id: id,
                            status: .syncing,
                            retryCount: row.retryCount + attempt + 1,
                            lastError: error.localizedDescription
                        )
                        continue
                    }
                    try pendingStore.updateStatus(
                        id: id,
                        status: .failed,
                        retryCount: row.retryCount + attempt + 1,
                        lastError: error.localizedDescription
                    )
                    return
                }
            }
        } catch {
            // Decode failure: do not double-POST; surface as a terminal failure
            let msg = "Invalid stored request: \(error.localizedDescription)"
            try pendingStore.updateStatus(
                id: id, status: .failed, retryCount: row.retryCount, lastError: msg
            )
        }
    }

    private func refreshQueueMetrics() async {
        do {
            guard let uid = currentUserId() else {
                pendingCount = 0
                failedCount = 0
                failedItems = []
                syncStatus = .idle
                return
            }
            let rows = try pendingStore.fetchAllSortedByCreatedAt(forUserId: uid)
            let outstanding = rows
                .filter { $0.pendingStatus == .pending || $0.pendingStatus == .syncing }
                .count
            let failedRows = rows.filter { $0.pendingStatus == .failed }
            pendingCount = outstanding
            failedCount = failedRows.count
            failedItems = failedRows.map(failedItem)
            if failedCount > 0 {
                syncStatus = .failed(unsyncedCount: failedCount)
            } else {
                syncStatus = .idle
            }
        } catch {
            Self.log.error("refreshQueueMetrics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func failedItem(from row: PendingTransaction) -> FailedPendingItem {
        let title: String
        if let request = try? requestDecoder.decode(APISmartTransactionCreateRequest.self, from: row.request) {
            title = [request.transactionType.capitalized, request.assetName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        } else {
            title = "Stored transaction"
        }
        return FailedPendingItem(id: row.id, title: title, detail: row.lastError)
    }
}
