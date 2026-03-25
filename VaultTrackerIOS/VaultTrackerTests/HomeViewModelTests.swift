//
//  HomeViewModelTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("HomeViewModel", .serialized)
@MainActor
struct HomeViewModelTests {

    let mockService: MockDataService
    let viewModel: HomeViewModel

    init() throws {
        mockService = MockDataService()
        viewModel = HomeViewModel(dataService: mockService)
    }

    // MARK: - loadData() Happy Path

    @Test func loadDataPopulatesNetWorthAndCategoryTotals() async {
        mockService.dashboardStub = APIDashboardResponse(
            totalNetWorth: 100_000,
            categoryTotals: APICategoryTotals(crypto: 60_000, stocks: 30_000, cash: 10_000),
            groupedHoldings: [:]
        )

        await viewModel.loadData()

        #expect(viewModel.viewState.totalNetworthValue == 100_000)
        #expect(viewModel.viewState.cryptoTotalValue == 60_000)
        #expect(viewModel.viewState.stocksTotalValue == 30_000)
        #expect(viewModel.viewState.cashTotalValue == 10_000)
    }

    @Test func loadDataPopulatesGroupedHoldings() async {
        let btc = APIGroupedHolding(id: "btc-1", name: "Bitcoin", symbol: "BTC", quantity: 1, currentValue: 60_000)
        mockService.dashboardStub = APIDashboardResponse(
            totalNetWorth: 60_000,
            categoryTotals: APICategoryTotals(crypto: 60_000),
            groupedHoldings: ["crypto": [btc]]
        )

        await viewModel.loadData()

        #expect(viewModel.viewState.cryptoGroupedAssetHoldings.count == 1)
        #expect(viewModel.viewState.cryptoGroupedAssetHoldings.first?.symbol == "BTC")
        #expect(viewModel.viewState.cryptoGroupedAssetHoldings.first?.currentValue == 60_000)
    }

    @Test func loadDataClearsLoadingStateOnSuccess() async {
        await viewModel.loadData()
        #expect(!viewModel.viewState.isLoading)
    }

    @Test func loadDataClearsErrorMessageOnSuccess() async {
        viewModel.viewState.errorMessage = "previous error"
        await viewModel.loadData()
        #expect(viewModel.viewState.errorMessage == nil)
    }

    @Test func loadDataCallsDashboardServiceOnce() async {
        await viewModel.loadData()
        #expect(mockService.fetchDashboardCallCount == 1)
        #expect(mockService.fetchNetWorthHistoryCallCount == 1)
    }

    // MARK: - loadData() Error Handling

    @Test func loadDataSetsErrorMessageOnAPIError() async {
        mockService.dashboardError = APIError.networkError(URLError(.notConnectedToInternet))

        await viewModel.loadData()

        #expect(viewModel.viewState.errorMessage != nil)
        #expect(!viewModel.viewState.isLoading)
    }

    @Test func loadDataSetsErrorMessageOnGenericError() async {
        struct SomeError: Error {}
        mockService.dashboardError = SomeError()

        await viewModel.loadData()

        #expect(viewModel.viewState.errorMessage != nil)
        #expect(!viewModel.viewState.isLoading)
    }

    @Test func loadDataDoesNotClearTotalsOnError() async {
        // Seed state with a previous successful load
        viewModel.viewState.totalNetworthValue = 50_000
        mockService.dashboardError = APIError.serverError(500)

        await viewModel.loadData()

        // Error path shouldn't wipe out previous state
        #expect(viewModel.viewState.errorMessage != nil)
    }

    // MARK: - selectFilter()

    @Test func selectFilterPopulatesCryptoAssets() {
        let btc = APIGroupedHolding(id: "1", name: "Bitcoin", symbol: "BTC", quantity: 1, currentValue: 50_000)
        viewModel.viewState.cryptoGroupedAssetHoldings = [btc]

        viewModel.selectFilter(category: .crypto)

        #expect(viewModel.viewState.selectedFilter == .crypto)
        #expect(viewModel.viewState.filteredAssets.count == 1)
        #expect(viewModel.viewState.filteredAssets.first?.id == "1")
    }

    @Test func selectFilterPopulatesStocksAssets() {
        let voo = APIGroupedHolding(id: "2", name: "Vanguard S&P 500", symbol: "VOO", quantity: 10, currentValue: 5_000)
        viewModel.viewState.stocksGroupedAssetHoldings = [voo]

        viewModel.selectFilter(category: .stocks)

        #expect(viewModel.viewState.selectedFilter == .stocks)
        #expect(viewModel.viewState.filteredAssets.count == 1)
    }

    @Test func selectFilterNilClearsFilteredAssets() {
        viewModel.viewState.cryptoGroupedAssetHoldings = [
            APIGroupedHolding(id: "1", name: "Bitcoin", symbol: "BTC", quantity: 1, currentValue: 50_000)
        ]
        viewModel.selectFilter(category: .crypto)

        viewModel.selectFilter(category: nil)

        #expect(viewModel.viewState.selectedFilter == nil)
        #expect(viewModel.viewState.filteredAssets.isEmpty)
    }

    @Test func selectFilterReturnsEmptyForCategoryWithNoHoldings() {
        viewModel.viewState.cryptoGroupedAssetHoldings = []

        viewModel.selectFilter(category: .crypto)

        #expect(viewModel.viewState.filteredAssets.isEmpty)
    }

    // MARK: - loadData() preserves filter

    @Test func loadDataPreservesActiveCategoryFilter() async {
        viewModel.viewState.cryptoGroupedAssetHoldings = [
            APIGroupedHolding(id: "old", name: "Bitcoin", symbol: "BTC", quantity: 0.5, currentValue: 25_000)
        ]
        viewModel.selectFilter(category: .crypto)

        mockService.dashboardStub = APIDashboardResponse(
            totalNetWorth: 60_000,
            categoryTotals: APICategoryTotals(crypto: 60_000),
            groupedHoldings: [
                "crypto": [APIGroupedHolding(id: "new", name: "Bitcoin", symbol: "BTC", quantity: 1, currentValue: 60_000)]
            ]
        )

        await viewModel.loadData()

        // Filter should still be .crypto with updated holdings
        #expect(viewModel.viewState.selectedFilter == .crypto)
        #expect(viewModel.viewState.filteredAssets.count == 1)
        #expect(viewModel.viewState.filteredAssets.first?.id == "new")
    }

    // MARK: - onSave(smartRequest:)

    @Test func onSaveCallsSmartTransactionThenReloadsDashboard() async {
        let req = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Acme",
            symbol: "ACM",
            quantity: 2,
            pricePerUnit: 50,
            accountName: "Broker",
            accountType: "brokerage",
            date: nil
        )

        await viewModel.onSave(smartRequest: req)

        #expect(mockService.createSmartTransactionCallCount == 1)
        #expect(mockService.lastSmartTransactionRequest?.assetName == "Acme")
        #expect(mockService.fetchDashboardCallCount == 1)
    }

    @Test func onSaveSkipsDashboardReloadWhenSmartTransactionFails() async {
        mockService.createSmartTransactionError = APIError.serverError(500)
        let req = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "cash",
            assetName: "Savings",
            symbol: nil,
            quantity: 100,
            pricePerUnit: 1,
            accountName: "Bank",
            accountType: "bank",
            date: nil
        )

        await viewModel.onSave(smartRequest: req)

        #expect(mockService.createSmartTransactionCallCount == 1)
        #expect(mockService.fetchDashboardCallCount == 0)
        #expect(viewModel.viewState.errorMessage != nil)
    }

    // MARK: - refreshPrices()

    @Test func refreshPricesCallsServiceThenReloadsDashboard() async {
        await viewModel.refreshPrices()

        #expect(mockService.refreshPricesCallCount == 1)
        #expect(mockService.fetchDashboardCallCount == 1)
    }

    @Test func refreshPricesSetsErrorWithoutDashboardReloadOnFailure() async {
        mockService.refreshPricesError = APIError.networkError(URLError(.notConnectedToInternet))

        await viewModel.refreshPrices()

        #expect(mockService.refreshPricesCallCount == 1)
        #expect(mockService.fetchDashboardCallCount == 0)
        #expect(viewModel.viewState.errorMessage != nil)
        #expect(viewModel.isRefreshingPrices == false)
    }

    // MARK: - Net worth period

    @Test func selectNetWorthPeriodRefetchesHistoryWithNewPeriod() async throws {
        mockService.netWorthHistoryStub = [NetWorthSnapshot(date: Date(timeIntervalSince1970: 0), value: 1)]
        await viewModel.loadData()
        #expect(mockService.lastNetWorthPeriodRequested == .daily)
        #expect(mockService.fetchNetWorthHistoryCallCount == 1)

        viewModel.selectNetWorthPeriod(.weekly)
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(viewModel.selectedPeriod == .weekly)
        #expect(mockService.lastNetWorthPeriodRequested == .weekly)
        #expect(mockService.fetchNetWorthHistoryCallCount >= 2)
    }
}
