//
//  APIServiceProtocol.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation

/// Defines all API operations the app can perform.
/// Conform to this protocol to provide a real or mock implementation.
protocol APIServiceProtocol {

    // MARK: - Dashboard

    /// Fetch aggregated dashboard data (net worth, category totals, grouped holdings).
    func fetchDashboard() async throws -> APIDashboardResponse

    // MARK: - Accounts

    /// Fetch all accounts for the authenticated user.
    func fetchAccounts() async throws -> [APIAccountResponse]

    /// Create a new account.
    func createAccount(_ request: APIAccountCreateRequest) async throws -> APIAccountResponse

    /// Update an existing account by ID.
    func updateAccount(id: String, _ request: APIAccountUpdateRequest) async throws -> APIAccountResponse

    /// Delete an account by ID.
    func deleteAccount(id: String) async throws

    // MARK: - Assets

    /// Fetch all assets for the authenticated user.
    func fetchAssets() async throws -> [APIAssetResponse]

    /// Fetch a single asset by ID.
    func fetchAsset(id: String) async throws -> APIAssetResponse

    /// Create a new asset.
    func createAsset(_ request: APIAssetCreateRequest) async throws -> APIAssetResponse

    // MARK: - Transactions

    /// Fetch all transactions for the authenticated user.
    func fetchTransactions() async throws -> [APITransactionResponse]

    /// Create a new transaction.
    func createTransaction(_ request: APITransactionCreateRequest) async throws -> APITransactionResponse

    /// Update an existing transaction by ID.
    func updateTransaction(id: String, _ request: APITransactionUpdateRequest) async throws -> APITransactionResponse

    /// Delete a transaction by ID.
    func deleteTransaction(id: String) async throws

    // MARK: - Net Worth History

    /// Fetch historical net worth snapshots.
    /// - Parameter period: Optional granularity (daily/weekly/monthly). Defaults to backend default when nil.
    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> APINetWorthHistoryResponse
}
