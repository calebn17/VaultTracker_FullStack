//
//  AssetMapperTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("AssetMapper", .serialized)
@MainActor
struct AssetMapperTests {

    // MARK: - ID Mapping

    @Test func mapsValidUUIDString() {
        let id = "550e8400-e29b-41d4-a716-446655440000"
        let asset = AssetMapper.toDomain(makeResponse(id: id))
        #expect(asset.id.uuidString.lowercased() == id)
    }

    @Test func fallsBackToNewUUIDForInvalidID() {
        let asset = AssetMapper.toDomain(makeResponse(id: "bad-id"))
        #expect(asset.id != UUID(uuidString: "bad-id"))
    }

    // MARK: - Symbol Fallback

    @Test func usesSymbolWhenPresent() {
        let asset = AssetMapper.toDomain(makeResponse(symbol: "BTC"))
        #expect(asset.symbol == "BTC")
    }

    @Test func fallsBackToNameWhenSymbolIsNil() {
        let asset = AssetMapper.toDomain(makeResponse(name: "Savings Account", symbol: nil))
        #expect(asset.symbol == "Savings Account")
    }

    // MARK: - Category Mapping

    @Test func mapsCrypto() {
        #expect(AssetMapper.toDomain(makeResponse(category: "crypto")).category == .crypto)
    }

    @Test func mapsStocks() {
        #expect(AssetMapper.toDomain(makeResponse(category: "stocks")).category == .stocks)
    }

    @Test func mapsCash() {
        #expect(AssetMapper.toDomain(makeResponse(category: "cash")).category == .cash)
    }

    @Test func mapsRealEstateSnakeCase() {
        #expect(AssetMapper.toDomain(makeResponse(category: "real_estate")).category == .realEstate)
    }

    @Test func mapsRealEstateCamelCase() {
        #expect(AssetMapper.toDomain(makeResponse(category: "realEstate")).category == .realEstate)
    }

    @Test func mapsRetirement() {
        #expect(AssetMapper.toDomain(makeResponse(category: "retirement")).category == .retirement)
    }

    @Test func unknownCategoryDefaultsToCash() {
        #expect(AssetMapper.toDomain(makeResponse(category: "commodities")).category == .cash)
    }

    // MARK: - Price Derivation

    @Test func derivesPriceFromCurrentValueAndQuantity() {
        let asset = AssetMapper.toDomain(makeResponse(quantity: 2.0, currentValue: 100_000))
        #expect(asset.price == 50_000)
    }

    @Test func priceIsZeroWhenQuantityIsZero() {
        let asset = AssetMapper.toDomain(makeResponse(quantity: 0, currentValue: 100_000))
        #expect(asset.price == 0)
    }

    // MARK: - Other Fields

    @Test func mapsNameQuantityValueAndDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = AssetMapper.toDomain(makeResponse(name: "Bitcoin", quantity: 1.5, currentValue: 75_000, lastUpdated: date))
        #expect(asset.name == "Bitcoin")
        #expect(asset.quantity == 1.5)
        #expect(asset.currentValue == 75_000)
        #expect(asset.lastUpdated == date)
    }

    // MARK: - Array Mapping

    @Test func mapsArrayOfResponses() {
        let responses = [
            makeResponse(name: "Bitcoin", symbol: "BTC"),
            makeResponse(name: "Ethereum", symbol: "ETH")
        ]
        let assets = AssetMapper.toDomain(responses)
        #expect(assets.count == 2)
        #expect(assets[0].name == "Bitcoin")
        #expect(assets[1].name == "Ethereum")
    }

    // MARK: - Helpers

    private func makeResponse(
        id: String = UUID().uuidString,
        name: String = "Test Asset",
        symbol: String? = "TST",
        category: String = "crypto",
        quantity: Double = 1.0,
        currentValue: Double = 1_000,
        lastUpdated: Date = Date()
    ) -> APIAssetResponse {
        APIAssetResponse(
            id: id,
            userId: "user-123",
            name: name,
            symbol: symbol,
            category: category,
            quantity: quantity,
            currentValue: currentValue,
            lastUpdated: lastUpdated
        )
    }
}
