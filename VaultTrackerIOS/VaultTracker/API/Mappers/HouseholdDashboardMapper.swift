//
//  HouseholdDashboardMapper.swift
//  VaultTracker
//
//  Maps GET /dashboard/household into UI-ready state (merged totals + per member).
//

import Foundation

/// Merged household dashboard (hero + category bar) and per-member slices.
struct HouseholdHomeViewState: Equatable {
    var totalNetWorth: Double
    var categoryTotals: APICategoryTotals
    var members: [MemberViewState]
}

/// One member row: totals and holdings by API category key ("crypto", …).
struct MemberViewState: Identifiable, Equatable {
    let userId: String
    let email: String?
    let totalNetWorth: Double
    let categoryTotals: APICategoryTotals
    let groupedByCategory: [String: [APIGroupedHolding]]

    var id: String { userId }

    func value(for category: AssetCategory) -> Double {
        switch category {
        case .crypto: return categoryTotals.crypto
        case .stocks: return categoryTotals.stocks
        case .cash: return categoryTotals.cash
        case .realEstate: return categoryTotals.realEstate
        case .retirement: return categoryTotals.retirement
        }
    }

    /// Holdings for a category, accepting either camelCase or legacy `real_estate` keys.
    func groupedHoldings(for category: AssetCategory) -> [APIGroupedHolding] {
        let keys = keys(for: category)
        for key in keys {
            if let holdings = groupedByCategory[key] { return holdings }
        }
        return []
    }

    private func keys(for category: AssetCategory) -> [String] {
        switch category {
        case .crypto:
            return ["crypto"]
        case .stocks:
            return ["stocks"]
        case .cash:
            return ["cash"]
        case .realEstate:
            return ["realEstate", "real_estate"]
        case .retirement:
            return ["retirement"]
        }
    }
}

enum HouseholdDashboardMapper {

    static func toViewState(_ response: APIHouseholdDashboardResponse) -> HouseholdHomeViewState {
        let members: [MemberViewState] = response.members.map { member in
            MemberViewState(
                userId: member.userId,
                email: member.email,
                totalNetWorth: member.totalNetWorth,
                categoryTotals: member.categoryTotals,
                groupedByCategory: member.groupedHoldings
            )
        }
        return HouseholdHomeViewState(
            totalNetWorth: response.totalNetWorth,
            categoryTotals: response.categoryTotals,
            members: members
        )
    }
}
