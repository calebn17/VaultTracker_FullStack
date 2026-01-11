
import Foundation
import SwiftUI
import SwiftData

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
    
    private var context: ModelContext
    private var dataService: DataService

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
    init(context: ModelContext) {
        self.context = context
        self.dataService = DataService(context: context)
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
        
        guard let quantityValue: Double = switch selectedCategory {
        case .cash, .realEstate: 1.0
        default: Double(quantity)
        } else {
            shouldShowAlert = true
            alertMessage = "Quantity must be a valid number"
            return nil
        }
        
        guard let priceValue = Double(pricePerUnit) else {
            shouldShowAlert = true
            alertMessage = "Price per unit must be a valid number"
            return nil
        }
        
        do {
            let account = try await getOrCreateAccount()
            return Transaction(
                transactionType: transactionType,
                quantity: quantityValue,
                pricePerUnit: priceValue,
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
        let existingAccount = try dataService.fetchAccount(named: trimmedName)
        
        if let account = existingAccount {
            return account
        } else {
            let newAccount = Account(name: trimmedName, accountType: accountType)
            try dataService.addAccount(newAccount)
            return newAccount
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
