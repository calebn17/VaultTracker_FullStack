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

    // MARK: - FIRE

    var fireProfileStub = APIFIREProfileResponse(
        id: "fp-mock",
        currentAge: 30,
        annualIncome: 100_000,
        annualExpenses: 50_000,
        targetRetirementAge: 60,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    var fireProfileError: Error?
    private(set) var fetchFIREProfileCallCount = 0

    func fetchFIREProfile() async throws -> APIFIREProfileResponse {
        fetchFIREProfileCallCount += 1
        if let fireProfileError { throw fireProfileError }
        return fireProfileStub
    }

    var updateFIREResult: APIFIREProfileResponse?
    var updateFIREError: Error?
    private(set) var updateFIREProfileCallCount = 0
    private(set) var lastFIREProfileInput: APIFIREProfileInput?

    func updateFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse {
        updateFIREProfileCallCount += 1
        lastFIREProfileInput = input
        if let updateFIREError { throw updateFIREError }
        if let updateFIREResult { return updateFIREResult }
        return APIFIREProfileResponse(
            id: fireProfileStub.id,
            currentAge: input.currentAge,
            annualIncome: input.annualIncome,
            annualExpenses: input.annualExpenses,
            targetRetirementAge: input.targetRetirementAge,
            createdAt: fireProfileStub.createdAt,
            updatedAt: Date()
        )
    }

    var fireProjectionStub: APIFIREProjectionResponse = MockDataService.makeDefaultFireProjectionStub()

    private static func makeDefaultFireProjectionStub() -> APIFIREProjectionResponse {
        let inputs = APIFIREProjectionInputs(
            currentAge: 30,
            annualIncome: 100_000,
            annualExpenses: 50_000,
            currentNetWorth: 200_000,
            targetRetirementAge: 60
        )
        let tier: (Double, Int?, Int?) -> APIFIRETargetTier = { amount, years, age in
            APIFIRETargetTier(targetAmount: amount, yearsToTarget: years, targetAge: age)
        }
        return APIFIREProjectionResponse(
            status: "reachable",
            unreachableReason: nil,
            inputs: inputs,
            allocation: nil,
            blendedReturn: 0.07,
            realBlendedReturn: 0.04,
            inflationRate: 0.03,
            annualSavings: 20_000,
            savingsRate: 0.2,
            fireTargets: APIFIRETargets(
                leanFire: tier(1, 20, 50),
                fire: tier(2, 25, 55),
                fatFire: tier(5, nil, 60)
            ),
            projectionCurve: [APIFIREProjectionPoint(age: 30, year: 2026, projectedValue: 200_000)],
            monthlyBreakdown: APIFIREMonthlyBreakdown(monthlySurplus: 2000, monthsToFire: 120),
            goalAssessment: nil
        )
    }
    var fireProjectionError: Error?
    private(set) var fetchFIREProjectionCallCount = 0

    func fetchFIREProjection() async throws -> APIFIREProjectionResponse {
        fetchFIREProjectionCallCount += 1
        if let fireProjectionError { throw fireProjectionError }
        return fireProjectionStub
    }

    var householdFIREProfileStub = APIFIREProfileResponse(
        id: "hfp-mock",
        currentAge: 35,
        annualIncome: 200_000,
        annualExpenses: 100_000,
        targetRetirementAge: 58,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    var householdFIREError: Error?
    private(set) var fetchHouseholdFIREProfileCallCount = 0

    func fetchHouseholdFIREProfile() async throws -> APIFIREProfileResponse {
        fetchHouseholdFIREProfileCallCount += 1
        if let householdFIREError { throw householdFIREError }
        return householdFIREProfileStub
    }

    var updateHouseholdFIREResult: APIFIREProfileResponse?
    var updateHouseholdFIREError: Error?
    private(set) var updateHouseholdFIREProfileCallCount = 0
    private(set) var lastHouseholdFIREProfileInput: APIFIREProfileInput?

    func updateHouseholdFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse {
        updateHouseholdFIREProfileCallCount += 1
        lastHouseholdFIREProfileInput = input
        if let updateHouseholdFIREError { throw updateHouseholdFIREError }
        if let updateHouseholdFIREResult { return updateHouseholdFIREResult }
        return APIFIREProfileResponse(
            id: householdFIREProfileStub.id,
            currentAge: input.currentAge,
            annualIncome: input.annualIncome,
            annualExpenses: input.annualExpenses,
            targetRetirementAge: input.targetRetirementAge,
            createdAt: householdFIREProfileStub.createdAt,
            updatedAt: Date()
        )
    }
}

enum MockError: Error, LocalizedError {
    case notConfigured(String)
    var errorDescription: String? {
        if case .notConfigured(let name) = self { return "\(name) not configured in mock" }
        return nil
    }
}
