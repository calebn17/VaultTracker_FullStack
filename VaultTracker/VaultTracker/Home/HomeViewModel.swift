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

    /// Kept for AddAssetModalView; removed in Phase 6.1 when SwiftData is fully removed.
    var context: ModelContext

    /// Queue of recently saved Transactions that need to be processed and grouped by Account in `groupTransactionsFor`
    var newTransactionToBeGroupedQueue: [Transaction] = []

    private var dataService: DataServiceProtocol
    private var assetManager: AssetManagerProtocol

    init(context: ModelContext, assetManager: AssetManagerProtocol = AssetManager()) {
        self.context = context
        self.dataService = DataService()  // No longer needs ModelContext (Phase 3.1)
        self.assetManager = assetManager
    }

    func loadData(transactions: [Transaction]) async {
        // Phase 3: prices come from the backend — no local refresh needed.
        // transactions param still driven by @Query for now; replaced in Phase 4.
        await loadAssets()
        loadViewState(transactions: transactions)
        await rebuildHistoricalSnapshots()
    }

    /// Bulk delete is not supported via the API client.
    /// Will be removed in Phase 6.1 when SwiftData is fully removed.
    func clearData() async {
        print("DEBUG: clearData() is not supported in API mode. Addressed in Phase 6.1.")
    }

    // MARK: - Private: Data Aggregation & Refreshing
    private func loadAssets() async {
        do {
            let loadedAssets = try await dataService.fetchAllAssets()
            self.assets = loadedAssets
        } catch {
            print("Failed to load assets: \(error)")
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
            // Find the matching asset in the local cache by symbol or name.
            // After loadAssets(), cache entries have server-side UUIDs.
            let matchingAsset: Asset?
            switch transaction.category {
            case .crypto, .stocks, .retirement:
                matchingAsset = assets.first(where: { $0.symbol == transaction.symbol })
            case .realEstate, .cash:
                matchingAsset = assets.first(where: { $0.name == transaction.name })
            }

            let assetId: String
            if let existing = matchingAsset {
                assetId = existing.id.uuidString
            } else {
                // New asset — create it on the server to obtain a server-side ID.
                let initialValue = transaction.pricePerUnit * transaction.quantity
                let categoryString: String
                switch transaction.category {
                case .crypto:     categoryString = "crypto"
                case .stocks:     categoryString = "stocks"
                case .cash:       categoryString = "cash"
                case .realEstate: categoryString = "real_estate"
                case .retirement: categoryString = "retirement"
                }
                let symbol: String? = (transaction.category == .cash || transaction.category == .realEstate)
                    ? nil : transaction.symbol
                let assetRequest = APIAssetCreateRequest(
                    name: transaction.name,
                    symbol: symbol,
                    category: categoryString,
                    quantity: transaction.quantity,
                    currentValue: initialValue
                )
                let newAsset = try await dataService.createAsset(assetRequest)
                assets.append(newAsset)
                assetId = newAsset.id.uuidString
            }

            // Post the transaction to the API.
            let txRequest = APITransactionCreateRequest(
                assetId: assetId,
                accountId: transaction.account.id.uuidString,
                transactionType: transaction.transactionType.rawValue.lowercased(),
                quantity: transaction.quantity,
                pricePerUnit: transaction.pricePerUnit,
                date: transaction.date
            )
            let savedTransaction = try await dataService.createTransaction(txRequest)

            // Refresh asset list so quantities/values reflect the backend update.
            await loadAssets()
            newTransactionToBeGroupedQueue.append(savedTransaction)
            calculateAssetTotals()
        } catch {
            print("Failed to save transaction: \(error)")
        }
    }

    // MARK: - Private: Chart Logic

    /// Phase 3.5: replaced SwiftData snapshot rebuild with a direct API history call.
    @MainActor
    private func rebuildHistoricalSnapshots() async {
        do {
            snapshots = try await dataService.fetchNetWorthHistory(period: nil)
        } catch {
            print("Error fetching net worth history: \(error)")
            snapshots = []
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

        /// If there are new transactions and the cache is not empty,
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

            /// Grouping transactions by symbol per each account
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

        // Phase 3.6: local price refresh removed — prices come from the backend.

        /// Cache the results
        switch category {
        case .cash: viewState.cashGroupedAssetHoldings = result
        case .stocks: viewState.stocksGroupedAssetHoldings = result
        case .crypto: viewState.cryptoGroupedAssetHoldings = result
        case .realEstate: viewState.realEstateGroupedAssetHoldings = result
        case .retirement: viewState.retirementGroupedAssetHoldings = result
        }
    }
}
