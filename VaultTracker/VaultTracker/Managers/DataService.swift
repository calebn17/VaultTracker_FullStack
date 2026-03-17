//
//  DataService.swift
//  VaultTracker
//

import Foundation

/// API-backed implementation of DataServiceProtocol.
///
/// Replaces the previous SwiftData-based implementation. All reads and writes
/// go through APIService, with Phase 2 mapper functions converting API response
/// types into the app's domain models.
///
/// Must run on the MainActor because Asset and NetWorthSnapshot are
/// `@MainActor @Model` classes whose initialisers require the main thread.
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

    // MARK: - Transaction Operations (Phase 3.2)

    func fetchAllTransactions() async throws -> [Transaction] {
        // Fetch transactions, assets, and accounts in parallel — all three are
        // needed to resolve the asset name/symbol/category and account reference
        // that the domain Transaction model embeds inline.
        async let txResponses     = api.fetchTransactions()
        async let assetResponses  = api.fetchAssets()
        async let accountResponses = api.fetchAccounts()

        let (txs, assets, accounts) = try await (txResponses, assetResponses, accountResponses)

        let domainAssets   = AssetMapper.toDomain(assets)
        let domainAccounts = AccountMapper.toDomain(accounts)

        let assetsByID   = Dictionary(uniqueKeysWithValues: zip(assets.map(\.id),   domainAssets))
        let accountsByID = Dictionary(uniqueKeysWithValues: zip(accounts.map(\.id), domainAccounts))

        return TransactionMapper.toDomain(txs, assetsByID: assetsByID, accountsByID: accountsByID)
    }

    func createTransaction(_ request: APITransactionCreateRequest) async throws -> Transaction {
        let response = try await api.createTransaction(request)

        // Fetch the created asset and all accounts to resolve the domain model.
        async let assetResponse    = api.fetchAsset(id: response.assetId)
        async let accountResponses = api.fetchAccounts()

        let (asset, accounts) = try await (assetResponse, accountResponses)
        let domainAsset    = AssetMapper.toDomain(asset)
        let domainAccounts = AccountMapper.toDomain(accounts)

        let assetsByID   = [asset.id: domainAsset]
        let accountsByID = Dictionary(uniqueKeysWithValues: zip(accounts.map(\.id), domainAccounts))

        guard let tx = TransactionMapper.toDomain(response, assetsByID: assetsByID, accountsByID: accountsByID) else {
            throw APIError.decodingError(
                NSError(domain: "DataService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not map created transaction to domain model"])
            )
        }
        return tx
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

    func clearAllData() async throws {
        try await api.clearAllData()
    }
}
