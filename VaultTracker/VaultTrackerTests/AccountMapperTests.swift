//
//  AccountMapperTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("AccountMapper")
@MainActor
struct AccountMapperTests {

    // MARK: - ID Mapping

    @Test func mapsValidUUIDString() {
        let id = "550e8400-e29b-41d4-a716-446655440000"
        let account = AccountMapper.toDomain(makeResponse(id: id))
        #expect(account.id.uuidString.lowercased() == id)
    }

    @Test func fallsBackToNewUUIDForInvalidID() {
        let account = AccountMapper.toDomain(makeResponse(id: "not-a-uuid"))
        #expect(account.id != UUID(uuidString: "not-a-uuid"))
    }

    // MARK: - Name & Date

    @Test func mapsNameAndCreationDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let account = AccountMapper.toDomain(makeResponse(name: "Coinbase", createdAt: date))
        #expect(account.name == "Coinbase")
        #expect(account.creationDate == date)
    }

    // MARK: - Account Type Mapping

    @Test func mapsBankAccountType() {
        #expect(AccountMapper.toDomain(makeResponse(accountType: "bank")).accountType == .bank)
    }

    @Test func mapsBrokerageAccountType() {
        #expect(AccountMapper.toDomain(makeResponse(accountType: "brokerage")).accountType == .brokerage)
    }

    @Test func mapsCryptoExchangeSnakeCase() {
        #expect(AccountMapper.toDomain(makeResponse(accountType: "crypto_exchange")).accountType == .cryptoExchange)
    }

    @Test func mapsCryptoExchangeCamelCase() {
        #expect(AccountMapper.toDomain(makeResponse(accountType: "cryptoExchange")).accountType == .cryptoExchange)
    }

    @Test func mapsRetirementToOther() {
        // No local retirement account type — maps to .other
        #expect(AccountMapper.toDomain(makeResponse(accountType: "retirement")).accountType == .other)
    }

    @Test func unknownTypeDefaultsToOther() {
        #expect(AccountMapper.toDomain(makeResponse(accountType: "savings")).accountType == .other)
    }

    // MARK: - Array Mapping

    @Test func mapsArrayOfResponses() {
        let responses = [
            makeResponse(id: "550e8400-e29b-41d4-a716-446655440000", name: "Chase"),
            makeResponse(id: "550e8400-e29b-41d4-a716-446655440001", name: "Fidelity")
        ]
        let accounts = AccountMapper.toDomain(responses)
        #expect(accounts.count == 2)
        #expect(accounts[0].name == "Chase")
        #expect(accounts[1].name == "Fidelity")
    }

    // MARK: - Helpers

    private func makeResponse(
        id: String = UUID().uuidString,
        name: String = "Test Account",
        accountType: String = "bank",
        createdAt: Date = Date()
    ) -> APIAccountResponse {
        APIAccountResponse(
            id: id,
            userId: "user-123",
            name: name,
            accountType: accountType,
            createdAt: createdAt
        )
    }
}
