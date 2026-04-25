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

    /// Portfolio allocation and performance summary.
    func fetchAnalytics() async throws -> APIAnalyticsResponse

    /// Refresh quoted asset prices from market data providers.
    func refreshPrices() async throws -> APIPriceRefreshResult

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

    /// Create a new asset.
    func createAsset(_ request: APIAssetCreateRequest) async throws -> APIAssetResponse

    // MARK: - Transactions

    /// Fetch all transactions for the authenticated user (enriched with nested asset + account).
    func fetchTransactions() async throws -> [APIEnrichedTransactionResponse]

    /// Create a transaction with server-side account + asset resolution.
    func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws -> APITransactionResponse

    /// Update an existing transaction by ID.
    func updateTransaction(id: String, _ request: APITransactionUpdateRequest) async throws -> APITransactionResponse

    /// Delete a transaction by ID.
    func deleteTransaction(id: String) async throws

    // MARK: - Net Worth History

    /// Fetch historical net worth snapshots.
    /// - Parameter period: Optional granularity (daily/weekly/monthly). Defaults to backend default when nil.
    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> APINetWorthHistoryResponse

    // MARK: - User Data

    /// Delete all financial data for the current user (accounts, assets, transactions, snapshots).
    func clearAllData() async throws

    // MARK: - Households

    /// Current household, or `nil` when the user is not in a household.
    /// Maps GET `/households/me` **404** with detail `notInHouseholdAPIDetail` to `nil`; other errors throw.
    func fetchHousehold() async throws -> APIHouseholdResponse?

    /// Create a household and become the first member (POST `/households`).
    func createHousehold() async throws -> APIHouseholdResponse

    /// Generate a short-lived invite code (POST `/households/invite-codes`).
    func generateInviteCode() async throws -> APIHouseholdInviteCodeResponse

    /// Join a household with an invite code (POST `/households/join`).
    func joinHousehold(code: String) async throws -> APIHouseholdResponse

    /// Leave the current household (DELETE `/households/me/membership`).
    func leaveHousehold() async throws

    // MARK: - Household dashboard & history

    /// Merged household dashboard (GET `/dashboard/household`).
    func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse

    /// Net worth history for the household (GET `/networth/history/household`).
    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws -> APINetWorthHistoryResponse

    // MARK: - Household FIRE (shared profile shape)

    /// GET `/households/me/fire-profile`
    func fetchHouseholdFIREProfile() async throws -> APIFIREProfileResponse

    /// PUT `/households/me/fire-profile`
    func updateHouseholdFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse

    // MARK: - Personal FIRE

    /// GET `/fire/profile`
    func fetchFIREProfile() async throws -> APIFIREProfileResponse

    /// PUT `/fire/profile`
    func updateFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse

    /// GET `/fire/projection`
    func fetchFIREProjection() async throws -> APIFIREProjectionResponse
}
