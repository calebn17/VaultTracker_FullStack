//
//  TransactionMapperTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("TransactionMapper")
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
