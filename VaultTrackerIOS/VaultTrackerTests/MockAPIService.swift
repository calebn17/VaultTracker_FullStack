//
//  MockAPIService.swift
//  VaultTrackerTests
//
//  Unscoped stub for `APIServiceProtocol` — defaults are empty/safe; tests override
//  the members `DataRepository` actually calls.
//

import Foundation
@testable import VaultTracker

/// Test double for the full API surface. Methods not under test return minimal valid values.
final class MockAPIService: APIServiceProtocol {
    // MARK: - Stubs (DataRepository)

    var fetchTransactionsError: Error?
    var fetchTransactionsResult: [APIEnrichedTransactionResponse] = []

    var fetchNetWorthHistoryError: Error?
    var fetchNetWorthHistoryResult = APINetWorthHistoryResponse(snapshots: [])

    var fetchHouseholdNetWorthHistoryError: Error?
    var fetchHouseholdNetWorthHistoryResult = APINetWorthHistoryResponse(snapshots: [])

    private(set) var lastNetWorthHistoryPeriod: APINetWorthPeriod?
    private(set) var lastHouseholdNetWorthHistoryPeriod: APINetWorthPeriod?

    func fetchTransactions() async throws -> [APIEnrichedTransactionResponse] {
        if let fetchTransactionsError { throw fetchTransactionsError }
        return fetchTransactionsResult
    }

    func fetchNetWorthHistory(period: APINetWorthPeriod?) async throws -> APINetWorthHistoryResponse {
        lastNetWorthHistoryPeriod = period
        if let fetchNetWorthHistoryError { throw fetchNetWorthHistoryError }
        return fetchNetWorthHistoryResult
    }

    func fetchHouseholdNetWorthHistory(period: APINetWorthPeriod?) async throws
        -> APINetWorthHistoryResponse {
        lastHouseholdNetWorthHistoryPeriod = period
        if let fetchHouseholdNetWorthHistoryError { throw fetchHouseholdNetWorthHistoryError }
        return fetchHouseholdNetWorthHistoryResult
    }

    // MARK: - Unused by DataRepository (minimal defaults)

    private let dashboardStub: APIDashboardResponse = {
        let crypto = [APIGroupedHolding(
            id: "1",
            name: "A",
            symbol: "A",
            quantity: 1,
            currentValue: 0
        )]
        return APIDashboardResponse(
            totalNetWorth: 0,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: ["crypto": crypto]
        )
    }()

    func fetchDashboard() async throws -> APIDashboardResponse { dashboardStub }
    func fetchAnalytics() async throws -> APIAnalyticsResponse {
        APIAnalyticsResponse(
            allocation: [:],
            performance: APIPerformanceBlock(
                totalGainLoss: 0,
                totalGainLossPercent: 0,
                costBasis: 0,
                currentValue: 0
            )
        )
    }
    func refreshPrices() async throws -> APIPriceRefreshResult {
        APIPriceRefreshResult(updated: [], skipped: [], errors: [])
    }
    func fetchAccounts() async throws -> [APIAccountResponse] { [] }
    func createAccount(_ request: APIAccountCreateRequest) async throws -> APIAccountResponse {
        throw MockError.notConfigured("createAccount")
    }
    func updateAccount(id: String, _ request: APIAccountUpdateRequest) async throws -> APIAccountResponse {
        throw MockError.notConfigured("updateAccount")
    }
    func deleteAccount(id: String) async throws {}
    func fetchAssets() async throws -> [APIAssetResponse] { [] }
    func createAsset(_ request: APIAssetCreateRequest) async throws -> APIAssetResponse {
        throw MockError.notConfigured("createAsset")
    }
    func createSmartTransaction(_ request: APISmartTransactionCreateRequest) async throws -> APITransactionResponse {
        throw MockError.notConfigured("createSmartTransaction in MockAPIService")
    }
    func updateTransaction(id: String, _ request: APITransactionUpdateRequest) async throws
        -> APITransactionResponse { throw MockError.notConfigured("updateTransaction") }
    func deleteTransaction(id: String) async throws {}
    func clearAllData() async throws {}
    func fetchHousehold() async throws -> APIHouseholdResponse? { nil }
    func createHousehold() async throws -> APIHouseholdResponse { throw MockError.notConfigured("createHousehold") }
    func generateInviteCode() async throws -> APIHouseholdInviteCodeResponse {
        throw MockError.notConfigured("generateInviteCode")
    }
    func joinHousehold(code: String) async throws -> APIHouseholdResponse {
        throw MockError.notConfigured("joinHousehold")
    }
    func leaveHousehold() async throws {}

    var householdDashboardStub: APIHouseholdDashboardResponse = APIHouseholdDashboardResponse(
        householdId: "h1",
        totalNetWorth: 0,
        categoryTotals: APICategoryTotals(),
        members: []
    )
    func fetchHouseholdDashboard() async throws -> APIHouseholdDashboardResponse { householdDashboardStub }
    func fetchHouseholdFIREProfile() async throws -> APIFIREProfileResponse { throw MockError.notConfigured("hf") }
    func updateHouseholdFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse {
        throw MockError.notConfigured("uhf")
    }
    func fetchFIREProfile() async throws -> APIFIREProfileResponse { throw MockError.notConfigured("ff") }
    func updateFIREProfile(_ input: APIFIREProfileInput) async throws -> APIFIREProfileResponse {
        throw MockError.notConfigured("uf")
    }
    func fetchFIREProjection() async throws -> APIFIREProjectionResponse { throw MockError.notConfigured("fp") }
}
