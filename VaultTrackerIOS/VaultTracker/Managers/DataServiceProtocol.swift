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

    func fetchAnalytics() async throws -> APIAnalyticsResponse

    func refreshPrices() async throws -> APIPriceRefreshResult

    // MARK: - Transactions

    func fetchAllTransactions() async throws -> [Transaction]
    func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws
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

    // MARK: - Households

    func fetchHousehold() async throws -> Household?

    func createHousehold() async throws -> Household

    func generateInviteCode() async throws -> HouseholdInviteCode

    func joinHousehold(code: String) async throws -> Household

    func leaveHousehold() async throws

    func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse

    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot]

    // MARK: - User Data

    func clearAllData() async throws
}
