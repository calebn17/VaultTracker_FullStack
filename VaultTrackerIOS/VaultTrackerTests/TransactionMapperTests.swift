//
//  TransactionMapperTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("TransactionMapper", .serialized)
@MainActor
struct TransactionMapperTests {

    private let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func enrichedMapsBuyWithSymbolAndBrokerageAccount() {
        let enriched = APIEnrichedTransactionResponse(
            id: "11111111-1111-1111-1111-111111111111",
            userId: "user-1",
            assetId: "asset-1",
            accountId: "acct-1",
            transactionType: "buy",
            quantity: 10,
            pricePerUnit: 150,
            totalValue: 1500,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-1", name: "Apple Inc", symbol: "AAPL", category: "stocks"),
            account: APIAccountSummary(id: "acct-1", name: "Broker", accountType: "brokerage")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.transactionType == .buy)
        #expect(tx.quantity == 10)
        #expect(tx.pricePerUnit == 150)
        #expect(tx.name == "Apple Inc")
        #expect(tx.symbol == "AAPL")
        #expect(tx.category == .stocks)
        #expect(tx.account.name == "Broker")
        #expect(tx.account.accountType == .brokerage)
        #expect(tx.id.uuidString.lowercased() == "11111111-1111-1111-1111-111111111111")
    }

    @Test func enrichedMapsSellAndFallsBackSymbolToNameForCash() {
        let enriched = APIEnrichedTransactionResponse(
            id: "22222222-2222-2222-2222-222222222222",
            userId: "user-1",
            assetId: "asset-2",
            accountId: "acct-2",
            transactionType: "sell",
            quantity: 500,
            pricePerUnit: 1,
            totalValue: 500,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-2", name: "Checking", symbol: nil, category: "cash"),
            account: APIAccountSummary(id: "acct-2", name: "Chase", accountType: "bank")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.transactionType == .sell)
        #expect(tx.symbol == "Checking")
        #expect(tx.category == .cash)
        #expect(tx.account.accountType == .bank)
    }

    // MARK: - Category Edge Cases

    @Test func mapsRealEstateTransaction() {
        let enriched = APIEnrichedTransactionResponse(
            id: "33333333-3333-3333-3333-333333333333",
            userId: "user-1",
            assetId: "asset-3",
            accountId: "acct-3",
            transactionType: "buy",
            quantity: 450_000,
            pricePerUnit: 1,
            totalValue: 450_000,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-3", name: "Oak Street Condo", symbol: nil, category: "realEstate"),
            account: APIAccountSummary(id: "acct-3", name: "RE Holdings", accountType: "other")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.category == .realEstate)
        #expect(tx.name == "Oak Street Condo")
        // symbol falls back to name for real estate (no symbol)
        #expect(tx.symbol == "Oak Street Condo")
    }

    @Test func mapsRetirementTransaction() {
        let enriched = APIEnrichedTransactionResponse(
            id: "44444444-4444-4444-4444-444444444444",
            userId: "user-1",
            assetId: "asset-4",
            accountId: "acct-4",
            transactionType: "buy",
            quantity: 100,
            pricePerUnit: 250,
            totalValue: 25_000,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-4", name: "Vanguard Target 2050", symbol: "VFFVX", category: "retirement"),
            account: APIAccountSummary(id: "acct-4", name: "Fidelity 401k", accountType: "brokerage")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.category == .retirement)
        #expect(tx.symbol == "VFFVX")
    }

    @Test func mapsSellTransactionType() {
        let enriched = APIEnrichedTransactionResponse(
            id: "55555555-5555-5555-5555-555555555555",
            userId: "user-1",
            assetId: "asset-5",
            accountId: "acct-5",
            transactionType: "sell",
            quantity: 2,
            pricePerUnit: 30_000,
            totalValue: 60_000,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-5", name: "Ethereum", symbol: "ETH", category: "crypto"),
            account: APIAccountSummary(id: "acct-5", name: "Kraken", accountType: "cryptoExchange")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.transactionType == .sell)
        // verify it is NOT buy (the default) — if mapping is broken this would be .buy
        #expect(tx.transactionType != .buy)
    }

    @Test func mapsTransactionWithNoSymbolFallsBackToName() {
        let enriched = APIEnrichedTransactionResponse(
            id: "66666666-6666-6666-6666-666666666666",
            userId: "user-1",
            assetId: "asset-6",
            accountId: "acct-6",
            transactionType: "buy",
            quantity: 5,
            pricePerUnit: 200,
            totalValue: 1000,
            date: sampleDate,
            asset: APIAssetSummary(id: "asset-6", name: "Unlisted Co", symbol: nil, category: "stocks"),
            account: APIAccountSummary(id: "acct-6", name: "Broker", accountType: "brokerage")
        )

        let tx = TransactionMapper.toDomain(enriched)

        #expect(tx.symbol == "Unlisted Co")
        #expect(tx.name == "Unlisted Co")
        #expect(tx.category == .stocks)
    }

    @Test func enrichedMapsArrayPreservesOrder() {
        let a = APIEnrichedTransactionResponse(
            id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            userId: "u", assetId: "a1", accountId: "c1",
            transactionType: "buy", quantity: 1, pricePerUnit: 1, totalValue: 1, date: sampleDate,
            asset: APIAssetSummary(id: "a1", name: "X", symbol: "X", category: "crypto"),
            account: APIAccountSummary(id: "c1", name: "Ex", accountType: "cryptoExchange")
        )
        let b = APIEnrichedTransactionResponse(
            id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            userId: "u", assetId: "a2", accountId: "c1",
            transactionType: "buy", quantity: 2, pricePerUnit: 2, totalValue: 4, date: sampleDate,
            asset: APIAssetSummary(id: "a2", name: "Y", symbol: "Y", category: "crypto"),
            account: APIAccountSummary(id: "c1", name: "Ex", accountType: "cryptoExchange")
        )

        let txs = TransactionMapper.toDomain([a, b])
        #expect(txs.count == 2)
        #expect(txs[0].name == "X")
        #expect(txs[1].name == "Y")
    }
}
