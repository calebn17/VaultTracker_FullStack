//
//  AddAssetFormViewModelIntegrationTests.swift
//  VaultTrackerTests
//
//  Integration tests for AddAssetFormViewModel. Each test exercises the
//  ViewModel's save() logic against a live backend, verifying smart-transaction
//  request shape, cash quantity encoding, and form validation.
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("Integration: AddAssetFormViewModel", .tags(.integration), .serialized)
@MainActor
struct AddAssetFormViewModelIntegrationTests {

    let formVM: AddAssetFormViewModel
    let api = APIService.shared

    init() async throws {
        AuthTokenProvider.isDebugSession = true
        try await DataService.shared.clearAllData()

        formVM = AddAssetFormViewModel()
    }

    // MARK: - Helpers

    /// Configure the form for a stocks transaction.
    private func configureStocksForm(
        accountName: String = "Test Brokerage",
        name: String = "Apple",
        symbol: String = "AAPL",
        quantity: String = "10",
        pricePerUnit: String = "150"
    ) {
        formVM.accountName = accountName
        formVM.accountType = .brokerage
        formVM.selectedCategory = .stocks
        formVM.name = name
        formVM.symbol = symbol
        formVM.quantity = quantity
        formVM.pricePerUnit = pricePerUnit
        formVM.transactionType = .buy
    }

    /// Configure the form for a cash transaction.
    private func configureCashForm(
        accountName: String = "Test Bank",
        name: String = "Savings",
        amount: String = "500"
    ) {
        formVM.accountName = accountName
        formVM.accountType = .bank
        formVM.selectedCategory = .cash
        formVM.name = name
        formVM.pricePerUnit = amount
        formVM.transactionType = .buy
    }

    // MARK: - Account creation (via smart transaction)

    @Test("save + smart POST creates a new account on the server when none exists")
    func saveCreatesNewAccountOnServer() async throws {
        configureStocksForm(accountName: "Brand New Brokerage")

        let request = try #require(await formVM.save())
        #expect(request.accountName == "Brand New Brokerage")
        _ = try await api.createSmartTransaction(request)

        let accounts = try await api.fetchAccounts()
        #expect(accounts.contains(where: { $0.name == "Brand New Brokerage" }))
    }

    @Test("save reuses existing server account — no duplicate created")
    func saveReusesExistingAccount() async throws {
        _ = try await api.createAccount(
            APIAccountCreateRequest(name: "Shared Brokerage", accountType: "brokerage")
        )

        configureStocksForm(accountName: "Shared Brokerage", symbol: "AAPL")
        _ = try await api.createSmartTransaction(try #require(await formVM.save()))

        formVM.symbol = "TSLA"
        formVM.name = "Tesla"
        _ = try await api.createSmartTransaction(try #require(await formVM.save()))

        let accounts = try await api.fetchAccounts()
        let matching = accounts.filter { $0.name == "Shared Brokerage" }
        #expect(matching.count == 1)
    }

    // MARK: - Cash quantity encoding

    @Test("save encodes cash as quantity=amount, pricePerUnit=1")
    func saveCashEncodesQuantityCorrectly() async throws {
        configureCashForm(amount: "750")

        let request = try #require(await formVM.save())

        #expect(request.quantity == 750)
        #expect(request.pricePerUnit == 1.0)
        #expect(request.category == "cash")
    }

    @Test("save encodes real estate as quantity=amount, pricePerUnit=1")
    func saveRealEstateEncodesQuantityCorrectly() async throws {
        formVM.accountName = "Property Account"
        formVM.accountType = .realEstate
        formVM.selectedCategory = .realEstate
        formVM.name = "123 Main St"
        formVM.pricePerUnit = "400000"
        formVM.transactionType = .buy

        let request = try #require(await formVM.save())

        #expect(request.quantity == 400_000)
        #expect(request.pricePerUnit == 1.0)
        #expect(request.category == "realEstate")
    }

    // MARK: - Stocks/crypto encoding

    @Test("save encodes stocks with correct quantity and price per unit")
    func saveStocksEncodesCorrectly() async throws {
        configureStocksForm(quantity: "10", pricePerUnit: "150")

        let request = try #require(await formVM.save())

        #expect(request.quantity == 10)
        #expect(request.pricePerUnit == 150)
        #expect(request.category == "stocks")
        #expect(request.symbol == "AAPL")
    }

    // MARK: - Form validation

    @Test("save returns nil and shows alert when account name is empty")
    func saveReturnsNilForEmptyAccountName() async throws {
        formVM.accountName = ""
        formVM.selectedCategory = .stocks
        formVM.name = "Apple"
        formVM.symbol = "AAPL"
        formVM.quantity = "10"
        formVM.pricePerUnit = "150"

        let result = await formVM.save()

        #expect(result == nil)
        #expect(formVM.shouldShowAlert == true)
    }

    @Test("save returns nil and shows alert when price is not a number")
    func saveReturnsNilForInvalidPrice() async throws {
        configureStocksForm(pricePerUnit: "not-a-number")

        let result = await formVM.save()

        #expect(result == nil)
        #expect(formVM.shouldShowAlert == true)
    }
}
