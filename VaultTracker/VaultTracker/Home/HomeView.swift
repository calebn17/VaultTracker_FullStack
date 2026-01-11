//
//  HomeView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var transactions: [Transaction]
    @StateObject var viewModel: HomeViewModel
    @State private var expandedCategories: Set<AssetCategory> = []
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(context: modelContext))
    }
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                
                filterBarView
                NetWorthChartView(snapshots: viewModel.snapshots)
                
                Text("Net Worth")
                    .font(.title2).bold()
                
                Text(viewModel.viewState.totalNetworthValue.currencyFormat())
                    .font(.system(size: 40, weight: .bold))
                
                // Bar representing asset composition
                if viewModel.viewState.totalNetworthValue > 0.0 {
                    assetBarView
                }
                
                // List of assets by category
                if viewModel.viewState.selectedFilter == nil {
                    assetListView
                } else {
                    aggregatedAssetListView(assets: viewModel.viewState.filteredAssets)
                }
            }
            .padding()
            .onChange(of: transactions) { _, _ in
                Task {
                    await viewModel.loadData(transactions: transactions)
                }
            }
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
                await viewModel.loadData(transactions: transactions)
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
        let totalWidth: CGFloat = UIScreen.main.bounds.width - 48 // account for padding
        return CGFloat(amount / totalAmount) * totalWidth
    }
    
    @ViewBuilder
    private func expandedDetailView(for category: AssetCategory) -> some View {
        let groupedData = switch category {
        case .crypto: viewModel.viewState.cryptoGroupedAssetHoldings
        case .stocks: viewModel.viewState.stocksGroupedAssetHoldings
        case .realEstate: viewModel.viewState.realEstateGroupedAssetHoldings
        case .cash: viewModel.viewState.cashGroupedAssetHoldings
        case .retirement: viewModel.viewState.retirementGroupedAssetHoldings
        }
        
        ForEach(groupedData.keys.sorted(), id: \.self) { accountName in
            VStack(alignment: .leading, spacing: 4) {
                Text(accountName)
                    .font(.headline)
                    .padding(.leading)
                
                if let accountHoldings = groupedData[accountName] {
                    ForEach(accountHoldings.keys.sorted(), id: \.self) { assetIdentifier in
                        if let holding = accountHoldings[assetIdentifier] {
                            HStack {
                                Text(assetIdentifier)
                                    .font(.body)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(holding.totalValue.currencyFormat())
                                        .font(.body).bold()
                                    
                                    let holdingsString: String = switch category {
                                    case .cash, .realEstate: ""
                                    case .stocks, .retirement: "\(holding.quantity.twoDecimalString) shares"
                                    case .crypto: "\(holding.quantity.twoDecimalString) coins"
                                    }
                                    
                                    Text(holdingsString)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func aggregatedAssetListView(assets: [Asset]) -> some View {
        VStack(spacing: 8) {
            ForEach(assets) { asset in
                HStack {
                    VStack(alignment: .leading) {
                        Text(asset.name)
                            .font(.headline)
                        Text(asset.symbol)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(asset.currentValue.currencyFormat())
                            .font(.body).bold()
                        let quantityString: String = switch asset.category {
                        case .cash, .realEstate: ""
                        case .stocks, .retirement: "\(asset.quantity.twoDecimalString) shares"
                        case .crypto: "\(asset.quantity.twoDecimalString) coins"
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

//#Preview {
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let schema = Schema([
//            Transaction.self, Account.self, NetWorthSnapshot.self, Asset.self
//        ])
//        let container = try! ModelContainer(for: schema, configurations: [config])
//
//        // Create mock accounts
//        let coinbase = Account(name: "Coinbase", accountType: .cryptoExchange)
//        let fidelity = Account(name: "Fidelity", accountType: .brokerage)
//        let chase = Account(name: "Chase", accountType: .bank)
//        let house = Account(name: "123 Main St", accountType: .realEstate)
//         
//
//        // Create mock transactions
//        let btcTx = Transaction(transactionType: .buy, quantity: 1.5, pricePerUnit: 50000, date: .now, name: "Bitcoin", symbol: "BTC", category: .crypto, account: coinbase)
//        let vooTx = Transaction(transactionType: .buy, quantity: 10, pricePerUnit: 500, date: .now, name: "Vanguard S&P 500", symbol: "VOO", category: .stocks, account: fidelity)
//        let cashTx = Transaction(transactionType: .buy, quantity: 10000, pricePerUnit: 1, date: .now, name: "Savings", category: .cash, account: chase)
//        let reTx = Transaction(transactionType: .buy, quantity: 1, pricePerUnit: 300_000, date: .now, name: "Main Property", category: .realEstate, account: house)
//        let mockTransactions = [btcTx, vooTx, cashTx, reTx]
//        
//        // Create mock Assets
////        let cryptoAssets = Asset(name: "Bitcoin", symbol: "BTC", value: 50_000)
////        let stockAssets = Asset(name: "Vanguard S&P 500", symbol: "VOO", value: 5_000)
////        let cashAssets = Asset(name: "Savings", value: 10_000)
////        let realEstateAssets = Asset(name: "123 Main St", symbol: "RE", value: 300_000)
////        let mockAssets: [Asset] = [cryptoAssets, stockAssets, realEstateAssets]
//        
//        // Insert mock data into the container
//        for i in 0..<4 {
//            container.mainContext.insert(mockTransactions[i])
////            container.mainContext.insert(mockAssets[i])
//        }
//
//        // Create the ViewModel with the mock context
//        let viewModel = HomeViewModel(context: container.mainContext)
//        
//        // Manually set the ViewModel's state for a predictable preview
//        Task {
//            await viewModel.loadData(transactions: mockTransactions)
//        }
//
//        NavigationView {
//           HomeView(modelContext: container.mainContext)
//        }
//        .modelContainer(container)
//}
