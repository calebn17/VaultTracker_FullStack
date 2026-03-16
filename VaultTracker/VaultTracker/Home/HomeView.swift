//
//  HomeView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @State private var expandedCategories: Set<AssetCategory> = []

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(context: modelContext))
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {

                if let errorMessage = viewModel.viewState.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(errorMessage)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            viewModel.viewState.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }

                filterBarView
                NetWorthChartView(snapshots: viewModel.snapshots)

                Text("Net Worth")
                    .font(.title2).bold()

                Text(viewModel.viewState.totalNetworthValue.currencyFormat())
                    .font(.system(size: 40, weight: .bold))

                if viewModel.viewState.totalNetworthValue > 0.0 {
                    assetBarView
                }

                if viewModel.viewState.selectedFilter == nil {
                    assetListView
                } else {
                    aggregatedAssetListView(holdings: viewModel.viewState.filteredAssets)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear Data") {
                        Task { await viewModel.clearData() }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.presentAddSheet()
                    }, label: {
                        Label("Add Transaction", systemImage: "plus")
                    })
                }
            }
            .sheet(isPresented: $viewModel.shouldPresentSheet) {
                NavigationView {
                    AddAssetModalView(context: viewModel.context) { transaction in
                        Task {
                            await viewModel.onSave(transaction: transaction)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
        .overlay {
            if viewModel.viewState.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.05))
            }
        }
    }

    private var filterBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button(action: {
                    viewModel.selectFilter(category: nil)
                }) {
                    Text("All")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.viewState.selectedFilter == nil ? Color.blue : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(viewModel.viewState.selectedFilter == nil ? .white : .primary)
                        .cornerRadius(20)
                }
                ForEach(AssetCategory.allCases, id: \.self) { category in
                    Button(action: {
                        viewModel.selectFilter(category: category)
                    }) {
                        Text(category.rawValue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.viewState.selectedFilter == category ? Color.blue : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(viewModel.viewState.selectedFilter == category ? .white : .primary)
                            .cornerRadius(20)
                    }
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
        .background(Color(.systemGray5))
        .cornerRadius(3)
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
            .fill(getAssetColor(assetCategory: assetCategory))
            .frame(width: width, height: 12)
            .cornerRadius(3)
    }

    private func assetListSection(assetCategory: AssetCategory) -> some View {
        let assetValue = getAssetValue(assetCategory: assetCategory)
        let isExpanded = expandedCategories.contains(assetCategory)

        return VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(getAssetColor(assetCategory: assetCategory))
                    .frame(width: 10, height: 10)

                Text(assetCategory.rawValue)
                    .font(.body)

                Spacer()

                if assetValue > 0.0 {
                    Text("\((assetValue / viewModel.viewState.totalNetworthValue * 100).twoDecimalString)%")
                        .foregroundStyle(.green)
                }

                Text(assetValue.currencyFormat())
                    .font(.body)
                    .bold()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
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

            if isExpanded {
                Divider()
                expandedDetailView(for: assetCategory)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func getAssetColor(assetCategory: AssetCategory) -> Color {
        switch assetCategory {
        case .crypto: return .cyan
        case .stocks: return .blue
        case .realEstate: return .pink
        case .cash: return .green
        case .retirement: return .purple
        }
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
        let holdings: GroupedAssetHolding = switch category {
        case .crypto:     viewModel.viewState.cryptoGroupedAssetHoldings
        case .stocks:     viewModel.viewState.stocksGroupedAssetHoldings
        case .realEstate: viewModel.viewState.realEstateGroupedAssetHoldings
        case .cash:       viewModel.viewState.cashGroupedAssetHoldings
        case .retirement: viewModel.viewState.retirementGroupedAssetHoldings
        }

        ForEach(holdings, id: \.id) { holding in
            HStack {
                Text(holding.symbol ?? holding.name)
                    .font(.body)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(holding.currentValue.currencyFormat())
                        .font(.body).bold()

                    let quantityString: String = switch category {
                    case .cash, .realEstate: ""
                    case .stocks, .retirement: "\(holding.quantity.twoDecimalString) shares"
                    case .crypto: "\(holding.quantity.twoDecimalString) coins"
                    }

                    Text(quantityString)
                        .font(.caption)
                        .foregroundColor(.gray)
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
                            .font(.headline)
                        if let symbol = holding.symbol {
                            Text(symbol)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(holding.currentValue.currencyFormat())
                            .font(.body).bold()

                        let quantityString: String
                        if let filter = viewModel.viewState.selectedFilter {
                            quantityString = switch filter {
                            case .cash, .realEstate: ""
                            case .stocks, .retirement: "\(holding.quantity.twoDecimalString) shares"
                            case .crypto: "\(holding.quantity.twoDecimalString) coins"
                            }
                        } else {
                            quantityString = ""
                        }

                        Text(quantityString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }
}
