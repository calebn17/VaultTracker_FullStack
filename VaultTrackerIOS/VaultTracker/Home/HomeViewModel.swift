// HomeViewModel.swift — drives HomeView.
//
// `loadData()` fetches the dashboard and net worth history. `onSave(smartRequest:)`
// posts `POST /transactions/smart` and reloads the dashboard.

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
    var errorMessage: String?
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var snapshots: [NetWorthSnapshot] = []
    @Published var viewState = HomeViewState()
    @Published var shouldPresentSheet: Bool = false
    @Published var selectedPeriod: APINetWorthPeriod = .daily
    @Published var isRefreshingPrices: Bool = false

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
    func onSave(smartRequest: APISmartTransactionCreateRequest) async {
        do {
            try await dataService.createSmartTransaction(smartRequest)
            await loadData()
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
    }

    func refreshPrices() async {
        isRefreshingPrices = true
        defer { isRefreshingPrices = false }
        do {
            _ = try await dataService.refreshPrices()
            await loadData()
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
    }

    func selectNetWorthPeriod(_ period: APINetWorthPeriod) {
        selectedPeriod = period
        Task { await rebuildHistoricalSnapshots() }
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
            snapshots = try await dataService.fetchNetWorthHistory(period: selectedPeriod)
        } catch {
            VTLog.shared.error("Error fetching net worth history", error: error, category: .ui)
            snapshots = []
        }
    }
}
