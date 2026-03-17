//
//  MockDataService.swift
//  VaultTrackerTests
//

import Foundation
@testable import VaultTracker

/// Configurable mock for DataServiceProtocol.
/// Set `dashboardStub` / `dashboardError` before calling loadData() in tests.
/// Methods not relevant to the test under exercise throw a plain error rather
/// than fatalError so tests fail cleanly if they hit an unexpected call.
final class MockDataService: DataServiceProtocol {

    // MARK: - Dashboard

    var dashboardStub = APIDashboardResponse(
        totalNetWorth: 0,
        categoryTotals: APICategoryTotals(),
        groupedHoldings: [:]
    )
    var dashboardError: Error?
    private(set) var fetchDashboardCallCount = 0

    func fetchDashboard() async throws -> APIDashboardResponse {
        fetchDashboardCallCount += 1
        if let error = dashboardError { throw error }
        return dashboardStub
    }

    // MARK: - Net Worth

    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot] {
        return []
    }

    // MARK: - Transactions

    func fetchAllTransactions() async throws -> [Transaction] { [] }

    func createTransaction(_ request: APITransactionCreateRequest) async throws -> Transaction {
        throw MockError.notConfigured("createTransaction")
    }

    func deleteTransaction(id: String) async throws {}

    // MARK: - Assets

    func fetchAllAssets() async throws -> [Asset] { [] }

    func createAsset(_ request: APIAssetCreateRequest) async throws -> Asset {
        throw MockError.notConfigured("createAsset")
    }

    // MARK: - Accounts

    func fetchAllAccounts() async throws -> [Account] { [] }

    func createAccount(_ request: APIAccountCreateRequest) async throws -> Account {
        throw MockError.notConfigured("createAccount")
    }

    func updateAccount(id: String, _ request: APIAccountUpdateRequest) async throws -> Account {
        throw MockError.notConfigured("updateAccount")
    }

    func deleteAccount(id: String) async throws {}

    // MARK: - User Data

    func clearAllData() async throws {}
}

enum MockError: Error, LocalizedError {
    case notConfigured(String)
    var errorDescription: String? {
        if case .notConfigured(let name) = self { return "\(name) not configured in mock" }
        return nil
    }
}
