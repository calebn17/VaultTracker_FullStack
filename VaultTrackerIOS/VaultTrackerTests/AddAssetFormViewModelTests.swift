//
//  AddAssetFormViewModelTests.swift
//  VaultTrackerTests
//
//  Unit tests for form validation logic in AddAssetFormViewModel.
//  These test the pure form logic (isFormValid, isAccountTypeValidForAssetCategory,
//  and the request encoding in save()) without hitting the network.
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("AddAssetFormViewModel — Unit", .serialized)
@MainActor
struct AddAssetFormViewModelTests {

    let viewModel: AddAssetFormViewModel

    init() throws {
        viewModel = AddAssetFormViewModel()
    }

    // MARK: - Default State

    @Test func transactionTypeDefaultsToBuy() {
        #expect(viewModel.transactionType == .buy)
    }

    @Test func categoryDefaultsToCash() {
        #expect(viewModel.selectedCategory == .cash)
    }

    // MARK: - Validation — Returns Nil

    @Test func saveReturnsNilWhenAssetNameIsEmpty() async {
        viewModel.name = ""
        viewModel.accountName = "My Bank"
        viewModel.pricePerUnit = "1000"
        viewModel.accountType = .bank
        viewModel.selectedCategory = .cash

        let result = await viewModel.save()

        #expect(result == nil)
    }

    @Test func saveReturnsNilWhenAccountNameIsEmpty() async {
        viewModel.name = "Savings"
        viewModel.accountName = ""
        viewModel.pricePerUnit = "500"
        viewModel.accountType = .bank
        viewModel.selectedCategory = .cash

        let result = await viewModel.save()

        #expect(result == nil)
    }

    @Test func saveReturnsNilWhenPriceIsNegative() async {
        viewModel.name = "Savings"
        viewModel.accountName = "My Bank"
        viewModel.pricePerUnit = "-50"
        viewModel.accountType = .bank
        viewModel.selectedCategory = .cash

        let result = await viewModel.save()

        #expect(result == nil)
    }

    @Test func saveReturnsNilWhenPriceIsNotANumber() async {
        viewModel.name = "Savings"
        viewModel.accountName = "My Bank"
        viewModel.pricePerUnit = "abc"
        viewModel.accountType = .bank
        viewModel.selectedCategory = .cash

        let result = await viewModel.save()

        #expect(result == nil)
    }

    @Test func saveReturnsNilWhenAccountTypeMismatchesCategory() async {
        // Crypto category requires cryptoExchange, cryptoWallet, or other
        viewModel.selectedCategory = .crypto
        viewModel.accountType = .bank  // incompatible
        viewModel.name = "Bitcoin"
        viewModel.symbol = "BTC"
        viewModel.quantity = "0.1"
        viewModel.pricePerUnit = "60000"
        viewModel.accountName = "My Bank"

        let result = await viewModel.save()

        #expect(result == nil)
    }

    // MARK: - Cash Encoding

    @Test func saveReturnsCashRequestWithCorrectEncoding() async throws {
        viewModel.selectedCategory = .cash
        viewModel.name = "Chase Savings"
        viewModel.accountName = "Chase"
        viewModel.accountType = .bank
        viewModel.pricePerUnit = "5000"  // dollar amount for cash
        viewModel.transactionType = .buy

        let result = await viewModel.save()

        let request = try #require(result)
        // For cash: pricePerUnit field is the dollar amount → becomes quantity
        // pricePerUnit is fixed at 1.0 so backend formula (qty * price) = dollar amount
        #expect(request.quantity == 5_000)
        #expect(request.pricePerUnit == 1.0)
        #expect(request.symbol == nil)
        #expect(request.category == "cash")
        #expect(request.assetName == "Chase Savings")
        #expect(request.accountName == "Chase")
        #expect(request.transactionType == "buy")
    }

    // MARK: - Crypto Encoding

    @Test func saveReturnsCryptoRequestWithCorrectEncoding() async throws{
        viewModel.selectedCategory = .crypto
        viewModel.name = "Bitcoin"
        viewModel.symbol = "BTC"
        viewModel.quantity = "0.5"
        viewModel.pricePerUnit = "60000"
        viewModel.accountName = "Coinbase"
        viewModel.accountType = .cryptoExchange
        viewModel.transactionType = .buy

        let result = await viewModel.save()

        let request = try #require(result)
        #expect(request.quantity == 0.5)
        #expect(request.pricePerUnit == 60_000)
        #expect(request.symbol == "BTC")
        #expect(request.category == "crypto")
        #expect(request.assetName == "Bitcoin")
        #expect(request.transactionType == "buy")
    }

    // MARK: - Sell Transaction

    @Test func saveReturnsSellTransactionType() async throws {
        viewModel.selectedCategory = .cash
        viewModel.name = "Emergency Fund"
        viewModel.accountName = "Chase"
        viewModel.accountType = .bank
        viewModel.pricePerUnit = "2500"
        viewModel.transactionType = .sell

        let result = await viewModel.save()

        let request = try #require(result)
        #expect(request.transactionType == "sell")
    }
}
