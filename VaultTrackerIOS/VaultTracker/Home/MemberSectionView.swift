//
//  MemberSectionView.swift
//  VaultTracker
//
//  Collapsible card for one household member: email (or fallback), per-category breakdown.
//

import SwiftUI

struct MemberSectionView: View {
    let member: MemberViewState
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                expandedCategories
            }
        }
        .background(VTColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("householdMemberSection_\(member.userId)")
    }

    private var displayName: String {
        member.email ?? "Household member"
    }

    private var header: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(VTFonts.body)
                        .foregroundStyle(VTColors.textPrimary)
                    Text("Total: \(member.totalNetWorth.currencyFormat())")
                        .font(VTFonts.monoBody)
                        .foregroundStyle(VTColors.textSubdued)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(VTColors.textSubdued)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("householdMemberHeaderButton_\(member.userId)")
        .accessibilityLabel(displayName)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Double tap to toggle member details.")
    }

    @ViewBuilder
    private var expandedCategories: some View {
        VStack(spacing: 0) {
            ForEach(AssetCategory.allCases, id: \.self) { category in
                memberCategoryBlock(category: category)
            }
        }
        .accessibilityIdentifier("householdMemberExpanded_\(member.userId)")
    }

    @ViewBuilder
    private func memberCategoryBlock(category: AssetCategory) -> some View {
        let value = member.value(for: category)
        let holdings = member.groupedHoldings(for: category)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle()
                    .fill(VTColors.categoryAccent(category))
                    .frame(width: 8, height: 8)
                Text(category.rawValue)
                    .font(VTFonts.caption)
                    .foregroundStyle(VTColors.textSubdued)
                Spacer()
                if member.totalNetWorth > 0, value > 0 {
                    Text("\((value / member.totalNetWorth * 100).twoDecimalString)%")
                        .font(VTFonts.monoCaption)
                        .foregroundStyle(VTColors.primary)
                }
                Text(value.currencyFormat())
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

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
                .padding(.vertical, 6)
            }
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
