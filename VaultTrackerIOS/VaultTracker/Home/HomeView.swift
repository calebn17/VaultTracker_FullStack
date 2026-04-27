//
//  HomeView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import UIKit

private enum HomeLedgerChrome {
    private static var configuredSegmentedAppearance = false

    static func configureNetWorthPeriodPickerAppearanceIfNeeded() {
        guard !configuredSegmentedAppearance else { return }
        configuredSegmentedAppearance = true
        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(VTColors.primary)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        seg.backgroundColor = UIColor(VTColors.surface)
    }
}

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @State private var expandedCategories: Set<AssetCategory> = []
    @State private var expandedMemberUserIds: Set<String> = []
    @State private var showClearConfirmation = false

    init(
        dataService: DataServiceProtocol = DataService.shared,
        dataRepository: DataRepositoryProtocol? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                dataService: dataService,
                dataRepository: dataRepository
            )
        )
    }

    private var useHouseholdMemberLayout: Bool {
        viewModel.isInHousehold && viewModel.householdMode && viewModel.householdViewState != nil
    }

    private var householdModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.householdMode },
            set: { viewModel.setHouseholdMode($0) }
        )
    }

    @ViewBuilder
    private var memberHouseholdList: some View {
        if let members = viewModel.householdViewState?.members {
            VStack(spacing: 8) {
                ForEach(members) { member in
                    MemberSectionView(
                        member: member,
                        isExpanded: Binding(
                            get: { expandedMemberUserIds.contains(member.userId) },
                            set: { isOn in
                                if isOn {
                                    expandedMemberUserIds.insert(member.userId)
                                } else {
                                    expandedMemberUserIds.remove(member.userId)
                                }
                            }
                        )
                    )
                }
            }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {

                if viewModel.isInHousehold {
                    Picker("Dashboard scope", selection: householdModeBinding) {
                        Text("Household").tag(true)
                        Text("Just Me").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("householdModePicker")
                }

                if let errorMessage = viewModel.viewState.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VTColors.error)
                        Text(errorMessage)
                            .font(VTFonts.body)
                            .foregroundStyle(VTColors.error)
                        Spacer()
                        Button {
                            viewModel.viewState.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(VTColors.textSubdued)
                        }
                        .accessibilityIdentifier("dismissErrorButton")
                    }
                    .padding()
                    .background(VTColors.error.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("errorBanner")
                }

                if viewModel.lastLoadServedFromCache {
                    HStack(spacing: 8) {
                        Image(systemName: "ipad.and.iphone")
                            .foregroundStyle(VTColors.textSubdued)
                        Text("Some figures may be from a saved copy on this device.")
                            .font(VTFonts.caption)
                            .foregroundStyle(VTColors.textSubdued)
                        Spacer(minLength: 0)
                    }
                    .accessibilityIdentifier("staleDataHint")
                }

                if !viewModel.isInHousehold || !viewModel.householdMode {
                    filterBarView
                }

                Picker("Period", selection: Binding(
                    get: { viewModel.selectedPeriod },
                    set: { viewModel.selectNetWorthPeriod($0) }
                )) {
                    Text("Daily").tag(APINetWorthPeriod.daily)
                    Text("Weekly").tag(APINetWorthPeriod.weekly)
                    Text("Monthly").tag(APINetWorthPeriod.monthly)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("netWorthPeriodPicker")

                NetWorthChartView(snapshots: viewModel.snapshots)
                    .accessibilityIdentifier("netWorthChart")

                Text("TOTAL NET WORTH")
                    .font(VTFonts.sectionHeader)
                    .foregroundStyle(VTColors.textSubdued)
                    .accessibilityIdentifier("netWorthTitleText")

                Text(viewModel.viewState.totalNetworthValue.currencyFormat())
                    .font(VTFonts.heroValue)
                    .foregroundStyle(VTColors.textPrimary)
                    .accessibilityIdentifier("netWorthValueText")

                if viewModel.viewState.totalNetworthValue > 0.0 {
                    assetBarView
                }

                if useHouseholdMemberLayout {
                    memberHouseholdList
                } else if viewModel.viewState.selectedFilter == nil {
                    assetListView
                } else {
                    aggregatedAssetListView(holdings: viewModel.viewState.filteredAssets)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear Data", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .tint(VTColors.error)
                    .accessibilityIdentifier("clearDataButton")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            Task { await viewModel.refreshPrices() }
                        } label: {
                            Label("Refresh Prices", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isRefreshingPrices)
                        .tint(VTColors.primary)
                        .accessibilityIdentifier("refreshPricesButton")

                        Button {
                            viewModel.presentAddSheet()
                        } label: {
                            Label("Add Transaction", systemImage: "plus")
                        }
                        .tint(VTColors.primary)
                        .accessibilityIdentifier("addTransactionButton")
                    }
                }
            }
            .sheet(isPresented: $viewModel.shouldPresentSheet) {
                NavigationView {
                    AddAssetModalView { request in
                        Task {
                            await viewModel.onSave(smartRequest: request)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .onAppear {
                HomeLedgerChrome.configureNetWorthPeriodPickerAppearanceIfNeeded()
            }
        }
        .accessibilityIdentifier("homeScrollView")
        .background(VTColors.background.ignoresSafeArea())
        .refreshable {
            await viewModel.loadData()
        }
        .confirmationDialog(
            "Clear all data?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                Task { await viewModel.clearData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your accounts, assets, and transactions.")
        }
        .onChange(of: viewModel.householdMode) { _, newValue in
            if newValue, viewModel.isInHousehold {
                expandedMemberUserIds = []
            }
        }
        .overlay {
            if viewModel.viewState.isLoading {
                ProgressView()
                    .tint(VTColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VTColors.background.opacity(0.7))
                    .accessibilityIdentifier("loadingOverlay")
            }
        }
    }

    private var filterBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    viewModel.selectFilter(category: nil)
                } label: {
                    Text("All")
                }
                .buttonStyle(FilterChipStyle(isSelected: viewModel.viewState.selectedFilter == nil))
                .accessibilityIdentifier("filterAllButton")
                ForEach(AssetCategory.allCases, id: \.self) { category in
                    Button {
                        viewModel.selectFilter(category: category)
                    } label: {
                        Text(category.rawValue)
                    }
                    .buttonStyle(FilterChipStyle(isSelected: viewModel.viewState.selectedFilter == category))
                    .accessibilityIdentifier("filterButton_\(category.rawValue)")
                }
            }
            .padding(.horizontal)
        }
    }

    private var assetBarView: some View {
        HStack(spacing: 2) {
            assetBarSection(assetCategory: .cash)
            assetBarSection(assetCategory: .stocks)
            assetBarSection(assetCategory: .crypto)
            assetBarSection(assetCategory: .realEstate)
            assetBarSection(assetCategory: .retirement)
        }
        .background(VTColors.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityIdentifier("assetBreakdownBar")
    }

    private var assetListView: some View {
        VStack(spacing: 8) {
            assetListSection(assetCategory: .cash)
            assetListSection(assetCategory: .stocks)
            assetListSection(assetCategory: .crypto)
            assetListSection(assetCategory: .realEstate)
            assetListSection(assetCategory: .retirement)
        }
    }

    private func assetBarSection(assetCategory: AssetCategory) -> some View {
        let assetValue = getAssetValue(assetCategory: assetCategory)
        let width = barWidth(for: assetValue)

        return Rectangle()
            .fill(VTColors.categoryAccent(assetCategory))
            .frame(width: width, height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private func assetListSection(assetCategory: AssetCategory) -> some View {
        let assetValue = getAssetValue(assetCategory: assetCategory)
        let isExpanded = expandedCategories.contains(assetCategory)

        return VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(VTColors.categoryAccent(assetCategory))
                    .frame(width: 10, height: 10)

                Text(assetCategory.rawValue)
                    .font(VTFonts.body)
                    .foregroundStyle(VTColors.textPrimary)

                Spacer()

                if assetValue > 0.0 {
                    Text("\((assetValue / viewModel.viewState.totalNetworthValue * 100).twoDecimalString)%")
                        .font(VTFonts.monoBody)
                        .foregroundStyle(VTColors.primary)
                }

                Text(assetValue.currencyFormat())
                    .font(VTFonts.monoLarge)
                    .foregroundStyle(VTColors.textPrimary)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(VTColors.textSubdued)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if isExpanded {
                        expandedCategories.remove(assetCategory)
                    } else {
                        expandedCategories.insert(assetCategory)
                    }
                }
            }
            .accessibilityIdentifier("categorySection_\(assetCategory.rawValue)")

            if isExpanded {
                expandedDetailView(for: assetCategory)
            }
        }
        .background(VTColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func getAssetValue(assetCategory: AssetCategory) -> Double {
        switch assetCategory {
        case .crypto: return viewModel.viewState.cryptoTotalValue
        case .stocks: return viewModel.viewState.stocksTotalValue
        case .realEstate: return viewModel.viewState.realEstateTotalValue
        case .cash: return viewModel.viewState.cashTotalValue
        case .retirement: return viewModel.viewState.retirementTotalValue
        }
    }

    private func barWidth(for amount: Double) -> CGFloat {
        let totalAmount = viewModel.viewState.totalNetworthValue
        guard totalAmount > 0 else { return 0 }
        let totalWidth: CGFloat = UIScreen.main.bounds.width - 48
        return CGFloat(amount / totalAmount) * totalWidth
    }

    @ViewBuilder
    private func expandedDetailView(for category: AssetCategory) -> some View {
        let holdings: GroupedAssetHolding = holdingsForExpandedDetail(category)

        ForEach(holdings, id: \.id) { holding in
            HStack {
                Text(holding.symbol ?? holding.name)
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(holding.currentValue.currencyFormat())
                        .font(VTFonts.monoLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(VTColors.textPrimary)
                    Text(quantityText(for: category, holding: holding))
                        .font(VTFonts.monoCaption)
                        .foregroundStyle(VTColors.textSubdued)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func aggregatedAssetListView(holdings: GroupedAssetHolding) -> some View {
        VStack(spacing: 8) {
            ForEach(holdings, id: \.id) { holding in
                HStack {
                    VStack(alignment: .leading) {
                        Text(holding.name)
                            .font(VTFonts.monoBody)
                            .foregroundStyle(VTColors.textPrimary)
                        if let symbol = holding.symbol {
                            Text(symbol)
                                .font(VTFonts.monoCaption)
                                .foregroundStyle(VTColors.textSubdued)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(holding.currentValue.currencyFormat())
                            .font(VTFonts.monoLarge)
                            .fontWeight(.bold)
                            .foregroundStyle(VTColors.textPrimary)

                        let quantityString = viewModel.viewState.selectedFilter.map { filter -> String in
                            switch filter {
                            case .cash, .realEstate: return ""
                            case .stocks, .retirement: return "\(holding.quantity.twoDecimalString) shares"
                            case .crypto: return "\(holding.quantity.twoDecimalString) coins"
                            }
                        } ?? ""

                        Text(quantityString)
                            .font(VTFonts.monoCaption)
                            .foregroundStyle(VTColors.textSubdued)
                    }
                }
                .padding()
                .background(VTColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func holdingsForExpandedDetail(_ category: AssetCategory) -> GroupedAssetHolding {
        switch category {
        case .crypto:
            return viewModel.viewState.cryptoGroupedAssetHoldings
        case .stocks:
            return viewModel.viewState.stocksGroupedAssetHoldings
        case .realEstate:
            return viewModel.viewState.realEstateGroupedAssetHoldings
        case .cash:
            return viewModel.viewState.cashGroupedAssetHoldings
        case .retirement:
            return viewModel.viewState.retirementGroupedAssetHoldings
        }
    }

    private func quantityText(for category: AssetCategory, holding: APIGroupedHolding) -> String {
        switch category {
        case .cash, .realEstate:
            return ""
        case .stocks, .retirement:
            return "\(holding.quantity.twoDecimalString) shares"
        case .crypto:
            return "\(holding.quantity.twoDecimalString) coins"
        }
    }
}
