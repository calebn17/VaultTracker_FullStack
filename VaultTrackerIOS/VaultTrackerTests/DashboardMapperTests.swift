//
//  DashboardMapperTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("DashboardMapper", .serialized)
struct DashboardMapperTests {

    // MARK: - Totals

    @Test func mapsNetWorthAndAllCategoryTotals() {
        let response = APIDashboardResponse(
            totalNetWorth: 200_000,
            categoryTotals: APICategoryTotals(
                crypto: 50_000,
                stocks: 75_000,
                cash: 25_000,
                realEstate: 40_000,
                retirement: 10_000
            ),
            groupedHoldings: [:]
        )

        let state = DashboardMapper.toViewState(response)

        #expect(state.totalNetworthValue == 200_000)
        #expect(state.cryptoTotalValue == 50_000)
        #expect(state.stocksTotalValue == 75_000)
        #expect(state.cashTotalValue == 25_000)
        #expect(state.realEstateTotalValue == 40_000)
        #expect(state.retirementTotalValue == 10_000)
    }

    @Test func emptyResponseProducesZeroTotals() {
        let response = APIDashboardResponse(
            totalNetWorth: 0,
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [:]
        )

        let state = DashboardMapper.toViewState(response)

        #expect(state.totalNetworthValue == 0)
        #expect(state.cryptoTotalValue == 0)
        #expect(state.cryptoGroupedAssetHoldings.isEmpty)
    }

    // MARK: - Grouped Holdings by Category Key

    @Test func mapsCryptoHoldings() {
        let holding = APIGroupedHolding(id: "btc-1", name: "Bitcoin", symbol: "BTC", quantity: 1.5, currentValue: 75_000)
        let response = makeDashboard(category: "crypto", holdings: [holding])

        let state = DashboardMapper.toViewState(response)

        #expect(state.cryptoGroupedAssetHoldings.count == 1)
        #expect(state.cryptoGroupedAssetHoldings.first?.id == "btc-1")
        #expect(state.cryptoGroupedAssetHoldings.first?.symbol == "BTC")
        #expect(state.cryptoGroupedAssetHoldings.first?.currentValue == 75_000)
    }

    @Test func mapsStocksHoldings() {
        let holding = APIGroupedHolding(id: "voo-1", name: "Vanguard S&P 500", symbol: "VOO", quantity: 10, currentValue: 5_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "stocks", holdings: [holding]))

        #expect(state.stocksGroupedAssetHoldings.count == 1)
        #expect(state.stocksGroupedAssetHoldings.first?.symbol == "VOO")
    }

    @Test func mapsCashHoldings() {
        let holding = APIGroupedHolding(id: "cash-1", name: "Savings", symbol: nil, quantity: 10_000, currentValue: 10_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "cash", holdings: [holding]))

        #expect(state.cashGroupedAssetHoldings.count == 1)
        #expect(state.cashGroupedAssetHoldings.first?.symbol == nil)
    }

    @Test func mapsRetirementHoldings() {
        let holding = APIGroupedHolding(id: "401k-1", name: "401k", symbol: "FXAIX", quantity: 50, currentValue: 8_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "retirement", holdings: [holding]))

        #expect(state.retirementGroupedAssetHoldings.count == 1)
    }

    @Test func mapsRealEstateWithSnakeCaseKey() {
        let holding = APIGroupedHolding(id: "re-1", name: "Main Property", symbol: nil, quantity: 1, currentValue: 500_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "real_estate", holdings: [holding]))

        #expect(state.realEstateGroupedAssetHoldings.count == 1)
    }

    @Test func mapsRealEstateWithCamelCaseKey() {
        let holding = APIGroupedHolding(id: "re-2", name: "Beach House", symbol: nil, quantity: 1, currentValue: 800_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "realEstate", holdings: [holding]))

        #expect(state.realEstateGroupedAssetHoldings.count == 1)
    }

    @Test func unknownCategoryKeyIsIgnored() {
        let holding = APIGroupedHolding(id: "x-1", name: "Unknown", symbol: nil, quantity: 1, currentValue: 1_000)
        let state = DashboardMapper.toViewState(makeDashboard(category: "commodities", holdings: [holding]))

        #expect(state.cryptoGroupedAssetHoldings.isEmpty)
        #expect(state.stocksGroupedAssetHoldings.isEmpty)
        #expect(state.cashGroupedAssetHoldings.isEmpty)
        #expect(state.realEstateGroupedAssetHoldings.isEmpty)
        #expect(state.retirementGroupedAssetHoldings.isEmpty)
    }

    @Test func multipleHoldingsPerCategory() {
        let btc = APIGroupedHolding(id: "btc", name: "Bitcoin", symbol: "BTC", quantity: 1, currentValue: 50_000)
        let eth = APIGroupedHolding(id: "eth", name: "Ethereum", symbol: "ETH", quantity: 10, currentValue: 30_000)
        let response = makeDashboard(category: "crypto", holdings: [btc, eth])

        let state = DashboardMapper.toViewState(response)

        #expect(state.cryptoGroupedAssetHoldings.count == 2)
    }

    // MARK: - Initial State

    @Test func freshStateHasNoFilterOrSelectedAssets() {
        let state = DashboardMapper.toViewState(
            APIDashboardResponse(totalNetWorth: 0, categoryTotals: APICategoryTotals(), groupedHoldings: [:])
        )
        #expect(state.selectedFilter == nil)
        #expect(state.filteredAssets.isEmpty)
        #expect(!state.isLoading)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Helpers

    private func makeDashboard(category: String, holdings: [APIGroupedHolding]) -> APIDashboardResponse {
        APIDashboardResponse(
            totalNetWorth: holdings.reduce(0) { $0 + $1.currentValue },
            categoryTotals: APICategoryTotals(),
            groupedHoldings: [category: holdings]
        )
    }
}
