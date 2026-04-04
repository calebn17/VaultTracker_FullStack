//
//  APIIntegrationTests.swift
//  VaultTrackerTests
//
//  Pure API-layer integration tests. These verify that APIService correctly
//  encodes requests, handles auth, and decodes responses — without involving
//  any ViewModel or domain-model mapping.
//
//  See HomeViewModelIntegrationTests and AddAssetFormViewModelIntegrationTests
//  for tests that exercise ViewModel logic end-to-end.
//

import Testing
import Foundation
@testable import VaultTracker

// MARK: - Tag

extension Tag {
    /// Marks tests that require a running backend server.
    /// Prerequisites:
    ///   1. `cd VaultTrackerAPI && ./start.sh`
    ///   2. `DEBUG_AUTH_ENABLED=true` in VaultTrackerAPI/.env
    ///   3. Set `API_HOST` in Xcode scheme env vars when testing on device.
    @Tag static var integration: Self
}

// MARK: - Suite

@Suite("Integration: API Layer", .tags(.integration), .serialized)
@MainActor
struct APIIntegrationTests {

    let api = APIService.shared

    init() async throws {
        AuthTokenProvider.shared.isDebugSession = true
        try await DataService.shared.clearAllData()
    }

    // MARK: - 5.2.1 Authentication

    @Test("Debug auth token reaches an authenticated endpoint")
    func authFlowEndToEnd() async throws {
        let dashboard = try await api.fetchDashboard()
        #expect(dashboard.totalNetWorth == 0)
    }

    // MARK: - 5.2.3 Account management

    @Test("Account create → fetch → update → delete flow")
    func accountCRUDFlow() async throws {
        // Create
        let created = try await api.createAccount(
            APIAccountCreateRequest(name: "My Bank", accountType: "bank")
        )
        #expect(created.name == "My Bank")
        #expect(created.accountType == "bank")

        // Fetch — verify it's in the list
        let accounts = try await api.fetchAccounts()
        #expect(accounts.contains(where: { $0.id == created.id }))

        // Update
        let updated = try await api.updateAccount(
            id: created.id,
            APIAccountUpdateRequest(name: "Renamed Bank")
        )
        #expect(updated.name == "Renamed Bank")

        // Delete
        try await api.deleteAccount(id: created.id)
        let afterDelete = try await api.fetchAccounts()
        #expect(!afterDelete.contains(where: { $0.id == created.id }))
    }

    // MARK: - 5.2.4 Net worth history

    @Test("Net worth history endpoint responds without error")
    func netWorthHistoryLoads() async throws {
        let response = try await api.fetchNetWorthHistory(period: nil)
        // Backend doesn't auto-create snapshots yet; just verify the endpoint responds.
        #expect(response.snapshots.count >= 0)
    }

    // MARK: - Backend 2.0

    @Test("GET /transactions returns enriched rows after smart create")
    func fetchTransactionsReturnsEnrichedShapeAfterSmartCreate() async throws {
        let req = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "crypto",
            assetName: "Bitcoin",
            symbol: "BTC",
            quantity: 0.1,
            pricePerUnit: 40_000,
            accountName: "API Test Exchange",
            accountType: "cryptoExchange",
            date: nil
        )
        _ = try await api.createSmartTransaction(req)

        let txs = try await api.fetchTransactions()
        #expect(txs.count >= 1)
        let first = try #require(txs.first)
        #expect(first.asset.name == "Bitcoin")
        #expect(first.asset.symbol == "BTC")
        #expect(first.account.name == "API Test Exchange")
        #expect(first.totalValue == 0.1 * 40_000)
    }

    @Test("GET /analytics decodes allocation and performance")
    func fetchAnalyticsLoads() async throws {
        let analytics = try await api.fetchAnalytics()
        #expect(analytics.performance.currentValue >= 0)
        #expect(analytics.performance.costBasis >= 0)
    }

    @Test("POST /prices/refresh returns structured result")
    func refreshPricesDecodes() async throws {
        let result = try await api.refreshPrices()
        #expect(result.updated.count >= 0)
        #expect(result.skipped.count >= 0)
        #expect(result.errors.count >= 0)
    }
}
