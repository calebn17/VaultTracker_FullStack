//
//  AssetCategoryView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/4/25.
//

import SwiftUI

struct AssetCategoryView: View {
    private var assets: [Asset]
    private var viewModel: HomeViewModel
    private var category: AssetCategory
    
    init(assets: [Asset], viewModel: HomeViewModel, category: AssetCategory) {
        self.assets = assets
        self.viewModel = viewModel
        self.category = category
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(assets) { asset in
                assetListRow(asset: asset)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func assetListRow(asset: Asset) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                let title = switch asset.category {
                    case .crypto, .retirement, .stocks: asset.symbol
                    case .cash: "Cash"
                    case .realEstate: "Real Estate"
                }
                
                Text(title)
                    .font(.headline)

                if category == .crypto || category == .retirement || category == .stocks {
                    Text(asset.symbol)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(asset.currentValue.currencyFormat())
                    .font(.headline)
                if category == .crypto || category == .retirement || category == .stocks {
                    Text("\(asset.quantity.twoDecimalString)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}
