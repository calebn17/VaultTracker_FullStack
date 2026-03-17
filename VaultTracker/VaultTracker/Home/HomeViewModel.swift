import Foundation

/// Flat list of holdings for a single asset category, sourced directly from the API.
typealias GroupedAssetHolding = [APIGroupedHolding]

struct HomeViewState {
    var selectedFilter: AssetCategory?
    var filteredAssets: GroupedAssetHolding = []

    var cryptoTotalValue: Double = 0.0
    var stocksTotalValue: Double = 0.0
    var cashTotalValue: Double = 0.0
    var retirementTotalValue: Double = 0.0
    var realEstateTotalValue: Double = 0.0
    var totalNetworthValue: Double = 0.0

    var cashGroupedAssetHoldings: GroupedAssetHolding = []
    var stocksGroupedAssetHoldings: GroupedAssetHolding = []
    var cryptoGroupedAssetHoldings: GroupedAssetHolding = []
    var realEstateGroupedAssetHoldings: GroupedAssetHolding = []
    var retirementGroupedAssetHoldings: GroupedAssetHolding = []

    var isLoading: Bool = false
    var errorMessage: String? = nil
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var snapshots: [NetWorthSnapshot] = []
    @Published var viewState = HomeViewState()
    @Published var shouldPresentSheet: Bool = false

    private var dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }

    func loadData() async {
        viewState.isLoading = true
        viewState.errorMessage = nil
        let selectedFilter = viewState.selectedFilter
        do {
            let dashboard = try await dataService.fetchDashboard()
            viewState = DashboardMapper.toViewState(dashboard)
            selectFilter(category: selectedFilter)
            await rebuildHistoricalSnapshots()
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
        viewState.isLoading = false
    }

    func clearData() async {
        viewState.isLoading = true
        viewState.errorMessage = nil
        do {
            try await dataService.clearAllData()
            viewState = HomeViewState()
            snapshots = []
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
        viewState.isLoading = false
    }

    @MainActor
    func onSave(transaction: Transaction) async {
        do {
            let allHoldings = viewState.cryptoGroupedAssetHoldings
                + viewState.stocksGroupedAssetHoldings
                + viewState.cashGroupedAssetHoldings
                + viewState.realEstateGroupedAssetHoldings
                + viewState.retirementGroupedAssetHoldings

            let assetId: String
            let matchingHolding: APIGroupedHolding?
            switch transaction.category {
            case .crypto, .stocks, .retirement:
                matchingHolding = allHoldings.first(where: { $0.symbol == transaction.symbol })
            case .realEstate, .cash:
                matchingHolding = allHoldings.first(where: { $0.name == transaction.name })
            }

            if let existing = matchingHolding {
                assetId = existing.id
            } else {
                let categoryString: String
                switch transaction.category {
                case .crypto:     categoryString = "crypto"
                case .stocks:     categoryString = "stocks"
                case .cash:       categoryString = "cash"
                case .realEstate: categoryString = "realEstate"
                case .retirement: categoryString = "retirement"
                }
                let symbol: String? = (transaction.category == .cash || transaction.category == .realEstate)
                    ? nil : transaction.symbol
                let assetRequest = APIAssetCreateRequest(
                    name: transaction.name,
                    symbol: symbol,
                    category: categoryString,
                    quantity: 0,
                    currentValue: 0
                )
                let newAsset = try await dataService.createAsset(assetRequest)
                assetId = newAsset.id.uuidString.lowercased()
            }

            let txRequest = APITransactionCreateRequest(
                assetId: assetId,
                accountId: transaction.account.id.uuidString.lowercased(),
                transactionType: transaction.transactionType.rawValue.lowercased(),
                quantity: transaction.quantity,
                pricePerUnit: transaction.pricePerUnit,
                date: transaction.date
            )
            _ = try await dataService.createTransaction(txRequest)
            await loadData()
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Modal Presentation

    func presentAddSheet() { shouldPresentSheet = true }
    func dismissAddSheet() { shouldPresentSheet = false }

    // MARK: - Filter (4.3)

    func selectFilter(category: AssetCategory?) {
        viewState.selectedFilter = category
        if let category {
            viewState.filteredAssets = switch category {
            case .crypto:     viewState.cryptoGroupedAssetHoldings
            case .stocks:     viewState.stocksGroupedAssetHoldings
            case .cash:       viewState.cashGroupedAssetHoldings
            case .realEstate: viewState.realEstateGroupedAssetHoldings
            case .retirement: viewState.retirementGroupedAssetHoldings
            }
        } else {
            viewState.filteredAssets = []
        }
    }

    // MARK: - Private

    private func rebuildHistoricalSnapshots() async {
        do {
            snapshots = try await dataService.fetchNetWorthHistory(period: nil)
        } catch {
            print("Error fetching net worth history: \(error)")
            snapshots = []
        }
    }
}
