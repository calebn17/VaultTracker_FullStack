//
//  DataRepository.swift
//  VaultTracker
//
//  Coordinates online reads/writes and SwiftData read-through caches for Home data:
//  personal and household dashboards, net worth history, and transactions, plus
//  offline smart-transaction queueing.
//  `DataService` and `APIService` types stay unchanged; this layer calls them and persists
//  encoded API payloads after successful fetches. Net worth history uses `APIServiceProtocol`
//  for `APINetWorthHistoryResponse` so the cache can store the same shape the backend returns.
//

import Combine
import Foundation

/// Thrown when offline or after a network failure and no SwiftData read-through row exists.
enum OfflineError: LocalizedError {
    case noCachedData
    case missingUserContext

    var errorDescription: String? {
        switch self {
        case .noCachedData: return "No saved copy is available while offline."
        case .missingUserContext: return "You must be signed in to load this data."
        }
    }
}

@MainActor
protocol DataRepositoryProtocol: AnyObject {
    func createTransaction(_ request: APISmartTransactionCreateRequest) async throws
    func fetchPersonalDashboard() async throws -> (APIDashboardResponse, isStale: Bool)
    func fetchHouseholdDashboard() async throws -> (APIHouseholdDashboardResponse, isStale: Bool)
    func fetchTransactions() async throws -> ([Transaction], isStale: Bool)
    func fetchPersonalNetWorthHistory(period: APINetWorthPeriod) async throws
        -> ([NetWorthSnapshot], isStale: Bool)
    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod) async throws
        -> ([NetWorthSnapshot], isStale: Bool)
}

@MainActor
final class DataRepository: ObservableObject, DataRepositoryProtocol {
    private let dataService: DataServiceProtocol
    private let api: APIServiceProtocol
    private let network: NetworkMonitoring
    private let cache: CachedDataStore
    private let syncManager: OfflineSyncManager
    private let currentUserId: () -> String?

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(
        dataService: DataServiceProtocol,
        api: APIServiceProtocol,
        network: NetworkMonitoring,
        cache: CachedDataStore,
        syncManager: OfflineSyncManager,
        currentUserId: @escaping () -> String?
    ) {
        self.dataService = dataService
        self.api = api
        self.network = network
        self.cache = cache
        self.syncManager = syncManager
        self.currentUserId = currentUserId
    }

    func createTransaction(_ request: APISmartTransactionCreateRequest) async throws {
        if network.isConnected {
            try await dataService.createSmartTransaction(request)
        } else {
            try syncManager.enqueue(request)
        }
    }

    func fetchPersonalDashboard() async throws -> (APIDashboardResponse, isStale: Bool) {
        let uid = try requireUserId()
        if network.isConnected {
            do {
                let dashboard = try await dataService.fetchDashboard()
                let data = try jsonEncoder.encode(dashboard)
                try cache.upsertPersonalDashboard(userId: uid, data: data)
                return (dashboard, false)
            } catch {
                return (try decodePersonalFromCacheOrThrow(userId: uid), true)
            }
        } else {
            return (try decodePersonalFromCacheOrThrow(userId: uid), true)
        }
    }

    func fetchHouseholdDashboard() async throws -> (APIHouseholdDashboardResponse, isStale: Bool) {
        let uid = try requireUserId()
        if network.isConnected {
            do {
                let dashboard = try await dataService.fetchHouseholdDashboard()
                let data = try jsonEncoder.encode(dashboard)
                try cache.upsertHouseholdDashboard(userId: uid, data: data)
                return (dashboard, false)
            } catch {
                return (try decodeHouseholdFromCacheOrThrow(userId: uid), true)
            }
        } else {
            return (try decodeHouseholdFromCacheOrThrow(userId: uid), true)
        }
    }

    func fetchTransactions() async throws -> ([Transaction], isStale: Bool) {
        let uid = try requireUserId()
        if network.isConnected {
            do {
                let responses = try await api.fetchTransactions()
                let domain = TransactionMapper.toDomain(responses)
                let rows: [(transactionId: String, data: Data)] = try responses.map { response in
                    (response.id, try jsonEncoder.encode(response))
                }
                try cache.replaceAllTransactions(for: uid, rows: rows)
                return (domain, false)
            } catch {
                return (try loadTransactionsFromCacheOrThrow(userId: uid), true)
            }
        } else {
            return (try loadTransactionsFromCacheOrThrow(userId: uid), true)
        }
    }

    func fetchPersonalNetWorthHistory(period: APINetWorthPeriod) async throws
        -> ([NetWorthSnapshot], isStale: Bool) {
        let uid = try requireUserId()
        if network.isConnected {
            do {
                let response = try await api.fetchNetWorthHistory(period: period)
                let data = try jsonEncoder.encode(response)
                try cache.upsertNetWorthHistory(
                    userId: uid,
                    scope: .personal,
                    period: period,
                    data: data
                )
                return (mapNetWorthResponse(response), false)
            } catch {
                return (try loadNetWorthFromCacheOrThrow(
                    userId: uid, scope: .personal, period: period
                ), true)
            }
        } else {
            return (try loadNetWorthFromCacheOrThrow(
                userId: uid, scope: .personal, period: period
            ), true)
        }
    }

    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod) async throws
        -> ([NetWorthSnapshot], isStale: Bool) {
        let uid = try requireUserId()
        if network.isConnected {
            do {
                let response = try await api.fetchHouseholdNetWorthHistory(period: period)
                let data = try jsonEncoder.encode(response)
                try cache.upsertNetWorthHistory(
                    userId: uid,
                    scope: .household,
                    period: period,
                    data: data
                )
                return (mapNetWorthResponse(response), false)
            } catch {
                return (try loadNetWorthFromCacheOrThrow(
                    userId: uid, scope: .household, period: period
                ), true)
            }
        } else {
            return (try loadNetWorthFromCacheOrThrow(
                userId: uid, scope: .household, period: period
            ), true)
        }
    }

    // MARK: - Private

    private func requireUserId() throws -> String {
        guard let id = currentUserId() else { throw OfflineError.missingUserContext }
        return id
    }

    private func mapNetWorthResponse(_ response: APINetWorthHistoryResponse) -> [NetWorthSnapshot] {
        response.snapshots.map { NetWorthSnapshot(date: $0.date, value: $0.value) }
    }

    private func decodePersonalFromCacheOrThrow(userId: String) throws -> APIDashboardResponse {
        guard let row = try cache.personalDashboard(userId: userId) else { throw OfflineError.noCachedData }
        do {
            return try jsonDecoder.decode(APIDashboardResponse.self, from: row.data)
        } catch {
            throw OfflineError.noCachedData
        }
    }

    private func decodeHouseholdFromCacheOrThrow(userId: String) throws -> APIHouseholdDashboardResponse {
        guard let row = try cache.householdDashboard(userId: userId) else { throw OfflineError.noCachedData }
        do {
            return try jsonDecoder.decode(APIHouseholdDashboardResponse.self, from: row.data)
        } catch {
            throw OfflineError.noCachedData
        }
    }

    private func loadTransactionsFromCacheOrThrow(userId: String) throws -> [Transaction] {
        let rows = try cache.transactions(for: userId)
        if rows.isEmpty { throw OfflineError.noCachedData }
        let decoded: [APIEnrichedTransactionResponse] = try rows.map { row in
            try jsonDecoder.decode(APIEnrichedTransactionResponse.self, from: row.data)
        }
        return TransactionMapper.toDomain(decoded)
    }

    private func loadNetWorthFromCacheOrThrow(
        userId: String, scope: CachedNetWorthScope, period: APINetWorthPeriod
    ) throws -> [NetWorthSnapshot] {
        guard let row = try cache.netWorthHistory(userId: userId, scope: scope, period: period) else {
            throw OfflineError.noCachedData
        }
        do {
            let response = try jsonDecoder.decode(APINetWorthHistoryResponse.self, from: row.data)
            return mapNetWorthResponse(response)
        } catch {
            throw OfflineError.noCachedData
        }
    }
}
