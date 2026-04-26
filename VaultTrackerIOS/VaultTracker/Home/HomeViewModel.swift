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
    /// `true` when the user belongs to a household (from `fetchHousehold()`).
    @Published var isInHousehold: Bool = false
    /// `true` = merged household dashboard; `false` = personal dashboard. Ignored when not in a household.
    @Published var householdMode: Bool = true
    /// Set when `isInHousehold && householdMode`; drives member sections and merged hero totals.
    @Published var householdViewState: HouseholdHomeViewState?
    @Published var shouldPresentSheet: Bool = false
    @Published var selectedPeriod: APINetWorthPeriod = .daily
    @Published var isRefreshingPrices: Bool = false

    private var dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }

    /// Toggles household vs personal dashboard and reloads. No-op if not in a household.
    func setHouseholdMode(_ value: Bool) {
        guard isInHousehold, value != householdMode else { return }
        householdMode = value
        Task { await loadData() }
    }

    func loadData() async {
        viewState.isLoading = true
        viewState.errorMessage = nil
        let selectedFilter = viewState.selectedFilter
        do {
            let household = try await dataService.fetchHousehold()
            isInHousehold = household != nil
            if isInHousehold, householdMode {
                let dashboard = try await dataService.fetchHouseholdDashboard()
                let merged = HouseholdDashboardMapper.toViewState(dashboard)
                householdViewState = merged
                applyHouseholdAggregateToViewState(merged)
            } else {
                householdViewState = nil
                let dashboard = try await dataService.fetchDashboard()
                viewState = DashboardMapper.toViewState(dashboard)
            }
            selectFilter(category: selectedFilter)
            await rebuildHistoricalSnapshots()
        } catch let error as APIError {
            viewState.errorMessage = error.errorDescription
        } catch {
            viewState.errorMessage = error.localizedDescription
        }
        viewState.isLoading = false
    }

    /// Copies merged household category totals into `HomeViewState` for the shared hero and category bar.
    private func applyHouseholdAggregateToViewState(_ aggregate: HouseholdHomeViewState) {
        var next = viewState
        next.totalNetworthValue = aggregate.totalNetWorth
        next.cryptoTotalValue = aggregate.categoryTotals.crypto
        next.stocksTotalValue = aggregate.categoryTotals.stocks
        next.cashTotalValue = aggregate.categoryTotals.cash
        next.realEstateTotalValue = aggregate.categoryTotals.realEstate
        next.retirementTotalValue = aggregate.categoryTotals.retirement
        next.cryptoGroupedAssetHoldings = []
        next.stocksGroupedAssetHoldings = []
        next.cashGroupedAssetHoldings = []
        next.realEstateGroupedAssetHoldings = []
        next.retirementGroupedAssetHoldings = []
        next.filteredAssets = []
        viewState = next
    }

    func clearData() async {
        viewState.isLoading = true
        viewState.errorMessage = nil
        do {
            try await dataService.clearAllData()
            viewState = HomeViewState()
            snapshots = []
            isInHousehold = false
            householdViewState = nil
            householdMode = true
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
            viewState.filteredAssets = groupedHoldings(for: category)
        } else {
            viewState.filteredAssets = []
        }
    }

    // MARK: - Private

    private func rebuildHistoricalSnapshots() async {
        do {
            if isInHousehold, householdMode {
                snapshots = try await dataService.fetchHouseholdNetWorthHistory(period: selectedPeriod)
            } else {
                snapshots = try await dataService.fetchNetWorthHistory(period: selectedPeriod)
            }
        } catch {
            VTLog.shared.error("Error fetching net worth history", error: error, category: .ui)
            snapshots = []
        }
    }

    private func groupedHoldings(for category: AssetCategory) -> GroupedAssetHolding {
        switch category {
        case .crypto:
            return viewState.cryptoGroupedAssetHoldings
        case .stocks:
            return viewState.stocksGroupedAssetHoldings
        case .cash:
            return viewState.cashGroupedAssetHoldings
        case .realEstate:
            return viewState.realEstateGroupedAssetHoldings
        case .retirement:
            return viewState.retirementGroupedAssetHoldings
        }
    }
}
