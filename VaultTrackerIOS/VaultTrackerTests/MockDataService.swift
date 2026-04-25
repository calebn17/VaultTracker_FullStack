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

    // MARK: - Analytics & prices

    var analyticsStub = APIAnalyticsResponse(
        allocation: [:],
        performance: APIPerformanceBlock(
            totalGainLoss: 0,
            totalGainLossPercent: 0,
            costBasis: 0,
            currentValue: 0
        )
    )
    var analyticsError: Error?
    private(set) var fetchAnalyticsCallCount = 0
    var refreshPricesStub = APIPriceRefreshResult(updated: [], skipped: [], errors: [])

    func fetchAnalytics() async throws -> APIAnalyticsResponse {
        fetchAnalyticsCallCount += 1
        if let error = analyticsError { throw error }
        return analyticsStub
    }

    func refreshPrices() async throws -> APIPriceRefreshResult {
        refreshPricesCallCount += 1
        if let error = refreshPricesError { throw error }
        return refreshPricesStub
    }

    private(set) var refreshPricesCallCount = 0
    var refreshPricesError: Error?

    // MARK: - Net Worth

    var netWorthHistoryStub: [NetWorthSnapshot] = []
    private(set) var fetchNetWorthHistoryCallCount = 0
    /// Last `period` passed to `fetchNetWorthHistory` (nil means the API default path).
    private(set) var lastNetWorthPeriodRequested: APINetWorthPeriod?

    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot] {
        fetchNetWorthHistoryCallCount += 1
        lastNetWorthPeriodRequested = period
        return netWorthHistoryStub
    }

    // MARK: - Transactions

    func fetchAllTransactions() async throws -> [Transaction] { [] }

    private(set) var createSmartTransactionCallCount = 0
    private(set) var lastSmartTransactionRequest: APISmartTransactionCreateRequest?
    var createSmartTransactionError: Error?

    func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws {
        createSmartTransactionCallCount += 1
        lastSmartTransactionRequest = request
        if let error = createSmartTransactionError { throw error }
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

    // MARK: - Households

    var householdStub: Household?
    var fetchHouseholdError: Error?
    private(set) var fetchHouseholdCallCount = 0

    func fetchHousehold() async throws -> Household? {
        fetchHouseholdCallCount += 1
        if let fetchHouseholdError { throw fetchHouseholdError }
        return householdStub
    }

    var createHouseholdStub = Household(
        id: "mock-household",
        members: [HouseholdMember(userId: "mock-user", email: nil)],
        createdAt: Date(timeIntervalSince1970: 0)
    )
    var createHouseholdError: Error?
    private(set) var createHouseholdCallCount = 0

    func createHousehold() async throws -> Household {
        createHouseholdCallCount += 1
        if let createHouseholdError { throw createHouseholdError }
        return createHouseholdStub
    }

    var inviteCodeStub = HouseholdInviteCode(code: "MOCKCODE", expiresAt: Date(timeIntervalSince1970: 0))
    var generateInviteCodeError: Error?
    private(set) var generateInviteCodeCallCount = 0

    func generateInviteCode() async throws -> HouseholdInviteCode {
        generateInviteCodeCallCount += 1
        if let generateInviteCodeError { throw generateInviteCodeError }
        return inviteCodeStub
    }

    var joinHouseholdStub: Household?
    var joinHouseholdError: Error?
    private(set) var joinHouseholdCallCount = 0
    private(set) var lastJoinHouseholdCode: String?

    func joinHousehold(code: String) async throws -> Household {
        joinHouseholdCallCount += 1
        lastJoinHouseholdCode = code
        if let joinHouseholdError { throw joinHouseholdError }
        return joinHouseholdStub ?? createHouseholdStub
    }

    var leaveHouseholdError: Error?
    private(set) var leaveHouseholdCallCount = 0

    func leaveHousehold() async throws {
        leaveHouseholdCallCount += 1
        if let leaveHouseholdError { throw leaveHouseholdError }
    }

    var householdDashboardStub = APIHouseholdDashboardResponse(
        householdId: "mock-household",
        totalNetWorth: 0,
        categoryTotals: APICategoryTotals(),
        members: []
    )
    var fetchHouseholdDashboardError: Error?
    private(set) var fetchHouseholdDashboardCallCount = 0

    func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse {
        fetchHouseholdDashboardCallCount += 1
        if let fetchHouseholdDashboardError { throw fetchHouseholdDashboardError }
        return householdDashboardStub
    }

    var householdNetWorthHistoryStub: [NetWorthSnapshot] = []
    private(set) var fetchHouseholdNetWorthHistoryCallCount = 0
    private(set) var lastHouseholdNetWorthPeriodRequested: APINetWorthPeriod?

    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws -> [NetWorthSnapshot] {
        fetchHouseholdNetWorthHistoryCallCount += 1
        lastHouseholdNetWorthPeriodRequested = period
        return householdNetWorthHistoryStub
    }
}

enum MockError: Error, LocalizedError {
    case notConfigured(String)
    var errorDescription: String? {
        if case .notConfigured(let name) = self { return "\(name) not configured in mock" }
        return nil
    }
}
