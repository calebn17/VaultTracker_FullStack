import SwiftData
import Foundation

enum DataModelType {
    case asset
    case transaction
    case snapshot
}

/// A service responsible for all interactions with the SwiftData database.
final class DataService {
    
    private var context: ModelContext
    private var assetManager: AssetManagerProtocol
    
    var assetPrices: [String : Double] = [:]
    var isAssetPriceRefreshed: Bool = false

    init(context: ModelContext, assetManager: AssetManagerProtocol = AssetManager()) {
        self.context = context
        self.assetManager = assetManager
    }

    // MARK: - Transaction C.R.U.D.
    func addTransaction(_ transaction: Transaction) async throws {
        try await insertModel(transaction)
    }

    func fetchAllTransactions() async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchTransactions(after date: Date) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date > date
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func deleteTransaction(_ transaction: Transaction) async throws {
       try await deleteModel(transaction)
    }

    func deleteAllTransactions() async throws {
        let transactions = try await fetchAllTransactions()
        for transaction in transactions {
            context.delete(transaction)
        }
        try await saveContext()
    }
    
    // MARK: - Asset C.R.U.D.
    func addAsset(_ asset: Asset) async throws {
        try await insertModel(asset)
    }

    func fetchAllAssets() async throws -> [Asset] {
        let descriptor = FetchDescriptor<Asset>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func deleteAsset(_ asset: Asset) async throws {
        try await deleteModel(asset)
    }

    func deleteAllAssets() async throws {
        let assets = try await fetchAllAssets()
        for asset in assets {
            context.delete(asset)
        }
        try await saveContext()
    }
    
    enum AssetDataError: Error {
        case missingSymbol
    }
    
    func fetchLatestPrice(for asset: Asset) async throws -> Double? {
        switch await asset.category {
        case .crypto:
            let response = try await assetManager.fetchCryptoAssetMarketData(symbol: asset.symbol, currency: .usd)
            return Double(response.exchangeRate)
            
        case .stocks, .retirement:
            let response = try await assetManager.fetchStocksAssetMarketData(symbol: asset.symbol)
            return Double(response.price)
            
        case .realEstate:
            // Add api call if I can find an API that has real estate data
            // Otherwise this will just be data that's pulled from the local storage (manually entered data)
            // Need to think about how to calculate equity
            return await asset.currentValue
        case .cash:
            return await asset.currentValue
        }
    }
    
    // MARK: - Refresh All Priced Assets Concurrently
    @MainActor
    func refreshAllPrices() async throws {
        let fetchedAssets = try await fetchAllAssets()
        
        /// For crypto, stocks, and retirement
        let pricedAssets = fetchedAssets.filter { $0.symbol != nil }
        try await withThrowingTaskGroup(of: Void.self) { [weak self] group in
            for asset in pricedAssets {
                group.addTask {
                    do {
                        if let newPrice = try await self?.fetchLatestPrice(for: asset) {
                            await MainActor.run {
                                asset.currentValue = newPrice * asset.quantity
                                self?.assetPrices[asset.symbol] = newPrice
                            }
                            
                            try await self?.saveContext()
                            self?.isAssetPriceRefreshed = true
                        }
                    } catch {
                        // By catching the error here and NOT re-throwing it, we allow the
                        // overall TaskGroup to continue even if one network call fails.
                        // The asset's currentValue simply remains unchanged.
                        print("DEBUG: Failed to refresh price for asset '\(await asset.name)'. Using stale value. Error: \(error.localizedDescription)")
                        self?.isAssetPriceRefreshed = false
                    }
                }
            }
            try await group.waitForAll()
        }
        
        /// For cash and real estate
        let otherAssets = fetchedAssets.filter { $0.symbol == nil }
        for asset in otherAssets {
            asset.currentValue = asset.quantity * asset.price
            try await saveContext()
        }
    }
    
    
    // MARK: - Account C.R.U.D.
    
    func addAccount(_ account: Account) throws {
        context.insert(account)
        // Note: Intentionally not saving here.
        // The save should be part of the larger transaction save operation.
    }
    
    func fetchAccount(named name: String) throws -> Account? {
        let predicate = #Predicate<Account> { $0.name == name }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Net Worth Snapshot C.R.U.D.
    
    func fetchAllNetworthSnapshots() async throws -> [NetWorthSnapshot] {
        let descriptor = FetchDescriptor<NetWorthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
    
    func addSnapshot(_ snapshot: NetWorthSnapshot) async throws {
        context.insert(snapshot)
        try await saveContext()
    }
    
    func deleteAllSnapshots() async throws {
        let snapshots = try await fetchAllNetworthSnapshots()
        for snapshot in snapshots {
            context.delete(snapshot)
        }
        try await saveContext()
    }
    
    // MARK: - Generic CRUD Operations
    func saveContext() async throws {
        try context.save()
    }
    
    func insertModel(_ model: any PersistentModel, shouldSave: Bool = true) async throws {
        context.insert(model)
        
        if shouldSave { try await saveContext() }
    }
    
    func deleteModel(_ model: any PersistentModel, shouldSave: Bool = true) async throws {
        context.delete(model)
        if shouldSave { try await saveContext() }
    }
}
