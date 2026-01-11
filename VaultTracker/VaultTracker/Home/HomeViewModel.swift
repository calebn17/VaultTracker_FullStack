import Foundation
import SwiftData

struct AssetHolding {
    let quantity: Double
    let totalValue: Double
}

/// [account name : [asset identifier : AssetHolding]]
/// asset identifier is either the symbol or name (for cash and real estate)
typealias GroupedAssetHolding = [String : [String : AssetHolding]]


struct HomeViewState {
    /// Filtered views
    var selectedFilter: AssetCategory?
    var filteredAssets: [Asset] = []
    
    var cryptoTotalValue: Double = 0.0
    var stocksTotalValue: Double = 0.0
    var cashTotalValue: Double = 0.0
    var retirementTotalValue: Double = 0.0
    var realEstateTotalValue: Double = 0.0
    var totalNetworthValue: Double = 0.0
    
    /// For the expanded view
    var cashGroupedAssetHoldings: GroupedAssetHolding = [:]
    var stocksGroupedAssetHoldings: GroupedAssetHolding = [:]
    var cryptoGroupedAssetHoldings: GroupedAssetHolding = [:]
    var realEstateGroupedAssetHoldings: GroupedAssetHolding = [:]
    var retirementGroupedAssetHoldings: GroupedAssetHolding = [:]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var snapshots: [NetWorthSnapshot] = []
    @Published var viewState = HomeViewState()
    @Published var shouldPresentSheet: Bool = false
    @Published var assets : [Asset] = []
    
    var context: ModelContext
    
    /// Queue of recently saved Transactions that need to be processed and grouped by Account in `groupTransactionsFor`
    var newTransactionToBeGroupedQueue: [Transaction] = []
    
    private var dataService: DataService
    private var assetManager: AssetManagerProtocol
    
    init(context: ModelContext, assetManager: AssetManagerProtocol = AssetManager()) {
        self.context = context
        self.dataService = DataService(context: context)
        self.assetManager = assetManager
    }
    
    func loadData(transactions: [Transaction]) async {
        dataService.isAssetPriceRefreshed = false
        await refreshPrices()
        await loadAssets()
        loadViewState(transactions: transactions)
        await rebuildHistoricalSnapshots()
    }
    
    func clearData() async {
        do {
            try await dataService.deleteAllTransactions()
            try await dataService.deleteAllAssets()
            try await dataService.deleteAllSnapshots()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
    
    // MARK: - Private: Data Aggregation & Refreshing
    private func loadAssets() async {
        do {
            let loadedAssets = try await dataService.fetchAllAssets()
            await MainActor.run {
                self.assets = loadedAssets
            }
        } catch {
            print("Failed to load assets: \(error)")
        }
    }
    
    private func refreshPrices() async {
        do {
            try await dataService.refreshAllPrices()
        } catch {
            print("Failed to refresh prices: \(error.localizedDescription)")
        }
    }
    
   @MainActor
    private func loadViewState(transactions: [Transaction]) {
        calculateAssetTotals()
        updateGroupHoldingsForAllCategories(transactions: transactions)
    }
    
    @MainActor
    private func calculateAssetTotals() {
        var cryptoTotal: Double = 0
        var stocksTotal: Double = 0
        var cashTotal: Double = 0
        var retirementTotal: Double = 0
        var realEstateTotal: Double = 0

        for asset in assets {
            switch asset.category {
            case .crypto: cryptoTotal += asset.currentValue
            case .stocks: stocksTotal += asset.currentValue
            case .cash: cashTotal += asset.currentValue
            case .retirement: retirementTotal += asset.currentValue
            case .realEstate: realEstateTotal += asset.currentValue
            }
        }
        
        viewState.cryptoTotalValue = cryptoTotal
        viewState.stocksTotalValue = stocksTotal
        viewState.cashTotalValue = cashTotal
        viewState.retirementTotalValue = retirementTotal
        viewState.realEstateTotalValue = realEstateTotal
        viewState.totalNetworthValue = cryptoTotal + stocksTotal + cashTotal + retirementTotal + realEstateTotal
    }
    
    private func updateGroupHoldingsForAllCategories(transactions: [Transaction]) {
        for category in AssetCategory.allCases {
            updateGroupHoldingsFor(category: category, from: transactions)
        }
        
        /// Clear queue
        newTransactionToBeGroupedQueue.removeAll()
    }
    
    @MainActor
    func onSave(transaction: Transaction) async {
        do {
            /// If the transaction involves an existing asset, then modify and update it
            let asset: Asset?
            switch transaction.category {
            case .crypto, .stocks, .retirement:
                asset = assets.filter({$0.symbol == transaction.symbol}).first
            case .realEstate, .cash:
                asset = assets.filter({ $0.name == transaction.name }).first
            }
            
            if let asset {
                switch transaction.category {
                case .crypto, .stocks, .retirement:
                    if transaction.transactionType == .buy {
                        asset.quantity += transaction.quantity
                    } else {
                        asset.quantity -= transaction.quantity
                    }
                    
                    /// For the price, compare the Asset.lastUpdated date with the Transaction date,
                    /// choose the most up-to-date price.
                    if (asset.lastUpdated < transaction.date) {
                        asset.price = transaction.pricePerUnit
                    }
                case .realEstate, .cash:
                    /// For these asset classes, need to update the "value" instead of the quantity
                    if transaction.transactionType == .buy {
                        asset.currentValue += transaction.pricePerUnit
                    } else {
                        asset.currentValue -= transaction.pricePerUnit
                    }
                }
                
                /// Updating the date for the Asset if needed
                if (asset.lastUpdated < transaction.date) {
                    asset.lastUpdated = transaction.date
                }
                
                try await dataService.saveContext()
            } else {
                /// Otherwise, create a new asset and save it
                let newAsset = Asset(
                    name: transaction.name,
                    category: transaction.category,
                    symbol: transaction.symbol,
                    quantity: transaction.quantity,
                    purchasePrice: transaction.pricePerUnit,
                    currentValue: transaction.pricePerUnit * transaction.quantity,
                    lastUpdated: transaction.date
                )
                try await dataService.addAsset(newAsset)
                assets.append(newAsset)
            }
            try await dataService.addTransaction(transaction)
            
            /// A new transaction needs to be grouped
            newTransactionToBeGroupedQueue.append(transaction)
            calculateAssetTotals()
        } catch {
            print("Failed to save transaction: \(error)")
        }
    }
    
    // MARK: - Private: Chart Logic
    @MainActor
    private func rebuildHistoricalSnapshots() async {
        do {
            let cachedSnapshots = try await dataService.fetchAllNetworthSnapshots().sorted(by: { $0.date < $1.date })
            let lastSnapshotDate = cachedSnapshots.last?.date ?? .distantPast
            
            let newTransactions = try await dataService.fetchTransactions(after: lastSnapshotDate)
            
            guard !newTransactions.isEmpty else {
                self.snapshots = cachedSnapshots
                return
            }
            
            var runningTotal = cachedSnapshots.last?.value ?? 0.0
            var newSnapshots: [NetWorthSnapshot] = []
            
            for transaction in newTransactions {
                let value = transaction.pricePerUnit * transaction.quantity
                if transaction.transactionType == .buy {
                    runningTotal += value
                } else {
                    runningTotal -= value
                }
                let newSnapshot = NetWorthSnapshot(date: transaction.date, value: runningTotal)
                newSnapshots.append(newSnapshot)
                try await dataService.addSnapshot(newSnapshot)
            }
            
            let allSnapshots = cachedSnapshots + newSnapshots
            
            let dailySnapshots = Dictionary(grouping: allSnapshots, by: { Calendar.current.startOfDay(for: $0.date) })
                .compactMap { $0.value.sorted(by: { $0.date < $1.date }).last } // Get the last snapshot of each day
                .sorted(by: { $0.date < $1.date })
            
            self.snapshots = dailySnapshots
        } catch {
            print("Error fetching transactions for snapshots: \(error)")
            self.snapshots = []
        }
    }
    
    // MARK: - Modal Presentation
    
    func presentAddSheet() {
        shouldPresentSheet = true
    }
    
    func dismissAddSheet() {
        shouldPresentSheet = false
    }

    func selectFilter(category: AssetCategory?) {
        viewState.selectedFilter = category
        
        if let selectedCategory = category {
            viewState.filteredAssets = self.assets.filter { $0.category == selectedCategory }.sorted(by: { $0.currentValue > $1.currentValue })
        } else {
            viewState.filteredAssets = []
        }
    }
    
    @MainActor
    func updateGroupHoldingsFor(category: AssetCategory, from transactions: [Transaction]) {
        let cachedGroupedHoldings = switch category {
        case .cash: viewState.cashGroupedAssetHoldings
        case .stocks: viewState.stocksGroupedAssetHoldings
        case .crypto: viewState.cryptoGroupedAssetHoldings
        case .realEstate: viewState.realEstateGroupedAssetHoldings
        case .retirement: viewState.retirementGroupedAssetHoldings
        }
        
        /// If no new transactions were added and the cache is not empty, then just use the cache
        if !cachedGroupedHoldings.isEmpty && newTransactionToBeGroupedQueue.isEmpty { return }
        
        /// If there are new transactions and  the cache is not empty,
        /// then process the transactions and add it to the cache and return
        if !cachedGroupedHoldings.isEmpty && !newTransactionToBeGroupedQueue.isEmpty {
            processGroupTransactions(transactions: newTransactionToBeGroupedQueue, category: category, storedGroupHoldings: cachedGroupedHoldings)
            return
        }
        
        processGroupTransactions(transactions: transactions, category: category)
    }
    
    @MainActor
    private func processGroupTransactions(
        transactions: [Transaction],
        category: AssetCategory,
        storedGroupHoldings: [String: [String: AssetHolding]] = [:]
    ) {
        /// Grouping the new transactions by account name in a dictionary [accountName : Transaction]
        let filteredTransactions = transactions.filter { $0.category == category }
        let transactionsGroupedByAccount = Dictionary(grouping: filteredTransactions, by: { $0.account.name })
        
        /// Starting off with the cached group holdings
        /// [accountName: [assetIdentifier : AssetHolding]]
        var result: [String: [String: AssetHolding]] = storedGroupHoldings
        
        /// Organizing transactions per account name
        for (accountName, accountTransactions) in transactionsGroupedByAccount {
            let groupedByAsset = Dictionary(grouping: accountTransactions, by: { $0.symbol })
            
            /// [assetIdentifier : AssetHolding]
            var identifierAssetHoldings: [String: AssetHolding] = [:]
            
            /// Grouping  transactions by symbol per each account
            for (assetIdentifier, assetTransactions) in groupedByAsset {
                let totalQuantity = assetTransactions.reduce(0) { $0 + ($1.transactionType == .buy ? $1.quantity : -$1.quantity) }
                let totalValue = assetTransactions.reduce(0) { $0 + ($1.transactionType == .buy ? ($1.quantity * $1.pricePerUnit) : -($1.quantity * $1.pricePerUnit)) }
                identifierAssetHoldings[assetIdentifier] = AssetHolding(quantity: totalQuantity, totalValue: totalValue)
            }
            
            /// if a result[accountName] already exists then update it with data from the new `identifierAssetHoldings`
            if let old = result[accountName] {
                result[accountName] = old.merging(identifierAssetHoldings, uniquingKeysWith: { old, new in
                    AssetHolding(quantity: old.quantity + new.quantity, totalValue: old.totalValue + new.totalValue)
                })
            } else {
                result[accountName] = identifierAssetHoldings
            }
        }
    
        let updatedResult = updatePricesForGroupedAssetHoldings(groupedAssetHoldings: result)
        
        /// Cache the results
        switch category {
        case .cash: viewState.cashGroupedAssetHoldings = updatedResult
        case .stocks: viewState.stocksGroupedAssetHoldings = updatedResult
        case .crypto: viewState.cryptoGroupedAssetHoldings = updatedResult
        case .realEstate: viewState.realEstateGroupedAssetHoldings = updatedResult
        case .retirement: viewState.retirementGroupedAssetHoldings = updatedResult
        }
    }
    
    @MainActor
    private func updatePricesForGroupedAssetHoldings(groupedAssetHoldings: GroupedAssetHolding) -> GroupedAssetHolding {
        // Need to update prices for the GroupedAssetHoldings with the latest prices for Crypto, Stocks, and Retirement categories
        var updatedGroupedAssetHolding = groupedAssetHoldings
        
        guard dataService.isAssetPriceRefreshed else { return updatedGroupedAssetHolding }
        
        for (accountName, assetIdentifierHoldings) in groupedAssetHoldings {
            for (assetIdentifier, holding) in assetIdentifierHoldings {
                guard let latestPrice = dataService.assetPrices[assetIdentifier] else { continue }
                
                let updatedValue = holding.quantity * latestPrice
                let updatedHolding = AssetHolding(
                    quantity: holding.quantity,
                    totalValue: updatedValue
                )
                
                updatedGroupedAssetHolding[accountName]?[assetIdentifier] = updatedHolding
            }
        }
        return updatedGroupedAssetHolding
    }
}
