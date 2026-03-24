//
//  HomeViewModelIntegrationTests.swift
//  VaultTrackerTests
//
//  Integration tests for HomeViewModel. Each test exercises real ViewModel
//  logic (loadData, onSave, clearData, selectFilter) against a live backend,
//  verifying that published state is correct after async operations complete.
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("Integration: HomeViewModel", .tags(.integration), .serialized)
@MainActor
struct HomeViewModelIntegrationTests {

    let viewModel: HomeViewModel
    let api = APIService.shared

    init() async throws {
        AuthTokenProvider.isDebugSession = true
        try await DataService.shared.clearAllData()

        viewModel = HomeViewModel()
    }

    // MARK: - loadData()

    @Test("loadData sets all-zero state when user has no data")
    func loadDataEmptyStateForFreshUser() async throws {
        await viewModel.loadData()

        #expect(viewModel.viewState.totalNetworthValue == 0)
        #expect(viewModel.viewState.stocksTotalValue == 0)
        #expect(viewModel.viewState.cryptoTotalValue == 0)
        #expect(viewModel.viewState.cashTotalValue == 0)
        #expect(viewModel.viewState.isLoading == false)
        #expect(viewModel.viewState.errorMessage == nil)
    }

    @Test("loadData populates viewState from real API data")
    func loadDataPopulatesStateFromAPI() async throws {
        // Seed data directly via API
        let account = try await api.createAccount(
            APIAccountCreateRequest(name: "Test Brokerage", accountType: "brokerage")
        )
        let asset = try await api.createAsset(
            APIAssetCreateRequest(name: "Apple", symbol: "AAPL", category: "stocks", quantity: 0, currentValue: 0)
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: asset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 10,
                pricePerUnit: 150,
                date: Date()
            )
        )

        await viewModel.loadData()

        #expect(viewModel.viewState.totalNetworthValue == 1500)
        #expect(viewModel.viewState.stocksTotalValue == 1500)
        #expect(viewModel.viewState.isLoading == false)
        #expect(viewModel.viewState.errorMessage == nil)

        let aapl = try #require(
            viewModel.viewState.stocksGroupedAssetHoldings.first(where: { $0.symbol == "AAPL" })
        )
        #expect(aapl.currentValue == 1500)
        #expect(aapl.quantity == 10)
    }

    @Test("loadData re-applies active category filter with refreshed holdings")
    func loadDataPreservesActiveCategoryFilter() async throws {
        // Seed initial crypto holding
        let account = try await api.createAccount(
            APIAccountCreateRequest(name: "Crypto Exchange", accountType: "crypto_exchange")
        )
        let asset = try await api.createAsset(
            APIAssetCreateRequest(name: "Bitcoin", symbol: "BTC", category: "crypto", quantity: 0, currentValue: 0)
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: asset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 1,
                pricePerUnit: 50_000,
                date: Date()
            )
        )

        // First load + set filter
        await viewModel.loadData()
        viewModel.selectFilter(category: .crypto)

        #expect(viewModel.viewState.selectedFilter == .crypto)
        #expect(viewModel.viewState.filteredAssets.count == 1)

        // Add more to the same asset on the server
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: asset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 1,
                pricePerUnit: 55_000,
                date: Date()
            )
        )

        // Reload — filter should persist and show updated value
        await viewModel.loadData()

        #expect(viewModel.viewState.selectedFilter == .crypto)
        #expect(viewModel.viewState.filteredAssets.count == 1)
        // Backend formula: current_value = total_quantity * latest_price_per_unit
        // (2 BTC × $55,000 = $110,000), not a sum of cost basis
        #expect(viewModel.viewState.filteredAssets.first?.currentValue == 110_000)
    }

    // MARK: - onSave()

    @Test("onSave with new asset creates holding and refreshes dashboard")
    func onSaveNewAssetAppearsInDashboard() async throws {
        let request = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Tesla",
            symbol: "TSLA",
            quantity: 5,
            pricePerUnit: 200,
            accountName: "My Brokerage",
            accountType: "brokerage",
            date: Date()
        )

        await viewModel.onSave(smartRequest: request)

        #expect(viewModel.viewState.totalNetworthValue == 1000)
        #expect(viewModel.viewState.stocksTotalValue == 1000)
        #expect(viewModel.viewState.errorMessage == nil)

        let tsla = viewModel.viewState.stocksGroupedAssetHoldings.first(where: { $0.symbol == "TSLA" })
        #expect(tsla != nil)
        #expect(tsla?.currentValue == 1000)
    }

    @Test("onSave on existing holding increases its value")
    func onSaveExistingAssetIncreasesValue() async throws {
        // Seed an initial holding via API
        let apiAccount = try await api.createAccount(
            APIAccountCreateRequest(name: "My Brokerage", accountType: "brokerage")
        )
        let asset = try await api.createAsset(
            APIAssetCreateRequest(name: "Tesla", symbol: "TSLA", category: "stocks", quantity: 0, currentValue: 0)
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: asset.id.lowercased(),
                accountId: apiAccount.id.lowercased(),
                transactionType: "buy",
                quantity: 5,
                pricePerUnit: 200,
                date: Date()
            )
        )

        // Load so the ViewModel knows about the existing TSLA holding
        await viewModel.loadData()
        #expect(viewModel.viewState.stocksTotalValue == 1000)

        let secondRequest = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Tesla",
            symbol: "TSLA",
            quantity: 5,
            pricePerUnit: 200,
            accountName: "My Brokerage",
            accountType: "brokerage",
            date: Date()
        )

        await viewModel.onSave(smartRequest: secondRequest)

        #expect(viewModel.viewState.stocksTotalValue == 2000)
        #expect(viewModel.viewState.stocksGroupedAssetHoldings.count == 1, "Should reuse the same asset, not create a second one")
    }

    // MARK: - clearData()

    @Test("clearData wipes server data and resets viewState to zero")
    func clearDataResetsViewModelAndBackend() async throws {
        // Seed data
        let account = try await api.createAccount(
            APIAccountCreateRequest(name: "Test Bank", accountType: "bank")
        )
        let asset = try await api.createAsset(
            APIAssetCreateRequest(name: "Savings", symbol: nil, category: "cash", quantity: 0, currentValue: 0)
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: asset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 1000,
                pricePerUnit: 1,
                date: Date()
            )
        )
        await viewModel.loadData()
        #expect(viewModel.viewState.totalNetworthValue == 1000)

        // Clear
        await viewModel.clearData()

        #expect(viewModel.viewState.totalNetworthValue == 0)
        #expect(viewModel.viewState.cashTotalValue == 0)
        #expect(viewModel.viewState.cashGroupedAssetHoldings.isEmpty)
        #expect(viewModel.snapshots.isEmpty)
        #expect(viewModel.viewState.isLoading == false)
        #expect(viewModel.viewState.errorMessage == nil)

        // Verify backend is also empty
        let dashboard = try await api.fetchDashboard()
        #expect(dashboard.totalNetWorth == 0)
    }

    // MARK: - selectFilter()

    @Test("selectFilter with real holdings shows only that category")
    func selectFilterWithRealHoldings() async throws {
        // Seed both stocks and cash
        let account = try await api.createAccount(
            APIAccountCreateRequest(name: "Mixed Account", accountType: "brokerage")
        )
        let stockAsset = try await api.createAsset(
            APIAssetCreateRequest(name: "Apple", symbol: "AAPL", category: "stocks", quantity: 0, currentValue: 0)
        )
        let cashAsset = try await api.createAsset(
            APIAssetCreateRequest(name: "Savings", symbol: nil, category: "cash", quantity: 0, currentValue: 0)
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: stockAsset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 10,
                pricePerUnit: 100,
                date: Date()
            )
        )
        _ = try await api.createTransaction(
            APITransactionCreateRequest(
                assetId: cashAsset.id.lowercased(),
                accountId: account.id.lowercased(),
                transactionType: "buy",
                quantity: 500,
                pricePerUnit: 1,
                date: Date()
            )
        )

        await viewModel.loadData()

        viewModel.selectFilter(category: .stocks)
        #expect(viewModel.viewState.selectedFilter == .stocks)
        #expect(viewModel.viewState.filteredAssets.count == 1)
        #expect(viewModel.viewState.filteredAssets.first?.symbol == "AAPL")

        viewModel.selectFilter(category: .cash)
        #expect(viewModel.viewState.filteredAssets.count == 1)
        #expect(viewModel.viewState.filteredAssets.first?.name == "Savings")

        viewModel.selectFilter(category: nil)
        #expect(viewModel.viewState.filteredAssets.isEmpty)
    }
}
