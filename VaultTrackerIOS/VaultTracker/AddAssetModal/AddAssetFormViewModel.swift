// AddAssetFormViewModel.swift — drives the "Add Asset / Transaction" form.
//
// On save, builds an `APISmartTransactionCreateRequest` for `POST /transactions/smart`.
// The backend resolves or creates the account and asset; the caller posts the request
// via `DataService.createSmartTransaction`.
// For cash and realEstate assets, `quantity` is the dollar amount and `pricePerUnit` is 1.

import Foundation
import SwiftUI

/// A view model that manages the state and logic for the Add Transaction form.
@MainActor
final class AddAssetFormViewModel: ObservableObject {

    // MARK: - Form Properties
    @Published var transactionType: TransactionType = .buy
    @Published var accountName: String = ""
    @Published var accountType: AccountType = .bank
    @Published var name: String = ""
    @Published var symbol: String = ""
    @Published var selectedCategory: AssetCategory = .cash
    @Published var quantity: String = ""
    @Published var pricePerUnit: String = ""
    @Published var date: Date = Date()

    /// Alert properties
    @Published var shouldShowAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - Computed Properties
    var isFormValid: Bool {
        guard !accountName.trimmingCharacters(in: .whitespaces).isEmpty,
              !name.trimmingCharacters(in: .whitespaces).isEmpty,
              isValidNonNegativeNumber(pricePerUnit)
        else { return false }

        if shouldShowSymbolField {
            return !symbol.trimmingCharacters(in: .whitespaces).isEmpty || isValidPositiveNumber(quantity)
        }

        return true
    }

    var isAccountTypeValidForAssetCategory: Bool {
        switch selectedCategory {
        case .crypto:
            return accountType == .cryptoExchange || accountType == .cryptoWallet || accountType == .other
        case .stocks, .retirement:
            return accountType == .brokerage || accountType == .other
        case .cash:
            return accountType == .bank || accountType == .physicalWallet || accountType == .other
        case .realEstate:
            return accountType == .realEstate || accountType == .other
        }
    }

    var shouldShowSymbolField: Bool {
        switch selectedCategory {
        case .crypto, .stocks, .retirement:
            return true
        case .cash, .realEstate:
            return false
        }
    }

    var quantityBinding: Binding<String> {
        Binding<String>(
            get: { self.quantity },
            set: { newValue in
                if newValue.isEmpty { self.quantity = ""; return }
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if filtered.components(separatedBy: ".").count > 2 { return }
                if let decIndex = filtered.firstIndex(of: ".") {
                    if filtered.distance(from: decIndex, to: filtered.endIndex) - 1 > 4 { return }
                }
                self.quantity = filtered
            }
        )
    }

    // MARK: - Public Methods
    func save() async -> APISmartTransactionCreateRequest? {
        guard isFormValid else {
            shouldShowAlert = true
            alertMessage = "Form is not valid"
            return nil
        }

        guard isAccountTypeValidForAssetCategory else {
            shouldShowAlert = true
            alertMessage = "Account type is not valid for selected asset category"
            return nil
        }

        guard let priceValue = Double(pricePerUnit) else {
            shouldShowAlert = true
            alertMessage = "Price per unit must be a valid number"
            return nil
        }

        let (finalQuantity, finalPricePerUnit): (Double, Double)
        switch selectedCategory {
        case .cash, .realEstate:
            finalQuantity = priceValue
            finalPricePerUnit = 1.0
        default:
            guard let q = Double(quantity) else {
                shouldShowAlert = true
                alertMessage = "Quantity must be a valid number"
                return nil
            }
            finalQuantity = q
            finalPricePerUnit = priceValue
        }

        let categoryAPI = apiCategoryString(selectedCategory)
        let symbolForAPI: String? = shouldShowSymbolField
            ? symbol.trimmingCharacters(in: .whitespaces)
            : nil
        let txType = transactionType == .buy ? "buy" : "sell"

        return APISmartTransactionCreateRequest(
            transactionType: txType,
            category: categoryAPI,
            assetName: name.trimmingCharacters(in: .whitespaces),
            symbol: symbolForAPI,
            quantity: finalQuantity,
            pricePerUnit: finalPricePerUnit,
            accountName: accountName.trimmingCharacters(in: .whitespaces),
            accountType: smartAPIAccountType(accountType),
            date: date
        )
    }

    // MARK: - Private Helpers

    private func apiCategoryString(_ category: AssetCategory) -> String {
        switch category {
        case .crypto: return "crypto"
        case .stocks: return "stocks"
        case .cash: return "cash"
        case .realEstate: return "realEstate"
        case .retirement: return "retirement"
        }
    }

    /// Values match Backend 2.0 / `SmartTransactionCreate` (e.g. `cryptoExchange`, `bank`).
    private func smartAPIAccountType(_ type: AccountType) -> String {
        switch type {
        case .bank: return "bank"
        case .brokerage: return "brokerage"
        case .cryptoExchange: return "cryptoExchange"
        case .physicalWallet, .cryptoWallet, .realEstate, .other: return "other"
        }
    }

    private func isValidNonNegativeNumber(_ string: String) -> Bool {
        guard let number = Double(string.trimmingCharacters(in: .whitespaces)) else { return false }
        return number >= 0
    }

    private func isValidPositiveNumber(_ string: String) -> Bool {
        guard let number = Double(string.trimmingCharacters(in: .whitespaces)) else { return false }
        return number > 0
    }
}
