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
                Text(assetTitle(for: asset.category, symbol: asset.symbol))
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)

                if category == .crypto || category == .retirement || category == .stocks {
                    Text(asset.symbol)
                        .font(VTFonts.monoCaption)
                        .foregroundStyle(VTColors.categoryAccent(category))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(asset.currentValue.currencyFormat())
                    .font(VTFonts.monoLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(VTColors.textPrimary)
                if category == .crypto || category == .retirement || category == .stocks {
                    Text("\(asset.quantity.twoDecimalString)")
                        .font(VTFonts.monoCaption)
                        .foregroundStyle(VTColors.textSubdued)
                }
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding()
        .background(VTColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func assetTitle(for category: AssetCategory, symbol: String) -> String {
        switch category {
        case .crypto, .retirement, .stocks:
            return symbol
        case .cash:
            return "Cash"
        case .realEstate:
            return "Real Estate"
        }
    }
}
