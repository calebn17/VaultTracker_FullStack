//
//  DataService.swift
//  VaultTracker
//

import Foundation

/// Application-layer service that satisfies `DataServiceProtocol` by delegating
/// every data operation to `APIService`. ViewModels depend on the protocol, not the
/// concrete class, so they can be tested with lightweight mock implementations.
///
/// Replaces the previous SwiftData-based implementation. All reads and writes
/// go through APIService, with Phase 2 mapper functions converting API response
/// types into the app's domain models.
///
@MainActor
final class DataService: DataServiceProtocol {

    // MARK: - Dependencies

    static let shared = DataService()

    private let api: APIServiceProtocol

    // MARK: - Init

    private init(api: APIServiceProtocol = APIService.shared) {
        self.api = api
    }

    // MARK: - Dashboard

    func fetchDashboard() async throws -> APIDashboardResponse {
        try await api.fetchDashboard()
    }

    func fetchAnalytics() async throws -> APIAnalyticsResponse {
        try await api.fetchAnalytics()
    }

    func refreshPrices() async throws -> APIPriceRefreshResult {
        try await api.refreshPrices()
    }

    // MARK: - Transaction Operations (Phase 3.2)

    func fetchAllTransactions() async throws -> [Transaction] {
        let responses = try await api.fetchTransactions()
        return TransactionMapper.toDomain(responses)
    }

    func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws {
        _ = try await api.createSmartTransaction(request)
    }

    func deleteTransaction(id: String) async throws {
        try await api.deleteTransaction(id: id)
    }

    // MARK: - Asset Operations (Phase 3.3)
    // Note: addAsset() is intentionally absent — assets are created by the
    // backend as a side-effect of transaction creation.

    func fetchAllAssets() async throws -> [Asset] {
        let responses = try await api.fetchAssets()
        return AssetMapper.toDomain(responses)
    }

    func createAsset(_ request: APIAssetCreateRequest) async throws -> Asset {
        let response = try await api.createAsset(request)
        return AssetMapper.toDomain(response)
    }

    // MARK: - Account Operations (Phase 3.4)

    func fetchAllAccounts() async throws -> [Account] {
        let responses = try await api.fetchAccounts()
        return AccountMapper.toDomain(responses)
    }

    func createAccount(_ request: APIAccountCreateRequest) async throws -> Account {
        let response = try await api.createAccount(request)
        return AccountMapper.toDomain(response)
    }

    func updateAccount(id: String, _ request: APIAccountUpdateRequest) async throws -> Account {
        let response = try await api.updateAccount(id: id, request)
        return AccountMapper.toDomain(response)
    }

    func deleteAccount(id: String) async throws {
        try await api.deleteAccount(id: id)
    }

    // MARK: - Net Worth Operations (Phase 3.5)
    // Note: addSnapshot() and rebuildHistoricalSnapshots() are removed —
    // the backend manages net-worth history automatically.

    func fetchNetWorthHistory(period: APINetWorthPeriod? = nil) async throws -> [NetWorthSnapshot] {
        let response = try await api.fetchNetWorthHistory(period: period)
        return response.snapshots.map { NetWorthSnapshot(date: $0.date, value: $0.value) }
    }

    // MARK: - User Data

    /// Wipes all financial data for the current user (transactions, snapshots, assets,
    /// accounts) via `DELETE /users/me/data`. Used by integration tests to reset state
    /// between runs; the user account itself is preserved.
    func clearAllData() async throws {
        try await api.clearAllData()
    }
}
