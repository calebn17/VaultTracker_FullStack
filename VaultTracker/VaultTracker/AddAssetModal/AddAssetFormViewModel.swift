
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
    
    private var dataService: DataServiceProtocol

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
    
    // MARK: - Init
    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }
    
    // MARK: - Public Methods
    func save() async -> Transaction? {
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

        // For cash and real estate the user enters a dollar amount, not a unit count.
        // We encode that as quantity=dollarAmount, pricePerUnit=1 so the backend
        // formula (current_value = quantity * price_per_unit) tracks the running
        // balance correctly across buy and sell transactions.
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

        do {
            let account = try await getOrCreateAccount()
            return Transaction(
                transactionType: transactionType,
                quantity: finalQuantity,
                pricePerUnit: finalPricePerUnit,
                date: date,
                name: name,
                symbol: shouldShowSymbolField ? symbol : name,
                category: selectedCategory,
                account: account
            )
        } catch {
            print("Failed to get or create account: \(error)")
            return nil
        }
    }
    
   
    // MARK: - Private Helpers
    
    private func getOrCreateAccount() async throws -> Account {
        let trimmedName = accountName.trimmingCharacters(in: .whitespaces)

        // Look up existing server accounts first so we reuse the server-side UUID.
        let allAccounts = try await dataService.fetchAllAccounts()
        if let existing = allAccounts.first(where: { $0.name == trimmedName }) {
            return existing
        }

        // Map local AccountType to the API's snake_case string.
        let accountTypeString: String
        switch accountType {
        case .bank:           accountTypeString = "bank"
        case .brokerage:      accountTypeString = "brokerage"
        case .cryptoExchange: accountTypeString = "crypto_exchange"
        default:              accountTypeString = "other"
        }

        let request = APIAccountCreateRequest(name: trimmedName, accountType: accountTypeString)
        return try await dataService.createAccount(request)
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
