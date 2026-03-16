//
//  DataServiceProtocol.swift
//  VaultTracker
//

import Foundation

/// Defines the data-access interface for the app's API-backed data layer.
///
/// `DataService` is the concrete implementation; test code can provide a mock.
protocol DataServiceProtocol: AnyObject {

    // MARK: - Dashboard

    func fetchDashboard() async throws -> APIDashboardResponse

    // MARK: - Transactions

    func fetchAllTransactions() async throws -> [Transaction]
    func createTransaction(_ request: APITransactionCreateRequest) async throws -> Transaction
    func deleteTransaction(id: String) async throws

    // MARK: - Assets

    func fetchAllAssets() async throws -> [Asset]
    func createAsset(_ request: APIAssetCreateRequest) async throws -> Asset

    // MARK: - Accounts

    func fetchAllAccounts() async throws -> [Account]
    func createAccount(_ request: APIAccountCreateRequest) async throws -> Account
    func updateAccount(id: String, _ request: APIAccountUpdateRequest) async throws -> Account
    func deleteAccount(id: String) async throws

    // MARK: - Net Worth

    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot]
}
