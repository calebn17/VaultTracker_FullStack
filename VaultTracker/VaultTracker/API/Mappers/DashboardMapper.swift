//
//  DashboardMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation

enum DashboardMapper {

    /// Convert an API dashboard response to the app's `HomeViewState`.
    ///
    /// **Shape mismatch (temporary):**
    /// The current `GroupedAssetHolding` type is `[accountName: [assetIdentifier: AssetHolding]]`
    /// but the API groups holdings by category, not by account.
    /// As a bridge, each category's holdings are stored with the holding name as the
    /// outer key and the symbol (or name) as the inner key. This keeps the existing
    /// UI rendering functional until Phase 4 restructures `HomeViewState` and
    /// `GroupedAssetHolding` to match the API's shape directly.
    static func toViewState(_ response: APIDashboardResponse) -> HomeViewState {
        var state = HomeViewState()

        // Totals
        state.totalNetworthValue    = response.totalNetWorth
        state.cryptoTotalValue      = response.categoryTotals.crypto
        state.stocksTotalValue      = response.categoryTotals.stocks
        state.cashTotalValue        = response.categoryTotals.cash
        state.realEstateTotalValue  = response.categoryTotals.realEstate
        state.retirementTotalValue  = response.categoryTotals.retirement

        // Grouped holdings — bridged from [category: [APIGroupedHolding]]
        for (category, holdings) in response.groupedHoldings {
            let grouped = makeGroupedHolding(from: holdings)
            switch category {
            case "crypto":                  state.cryptoGroupedAssetHoldings    = grouped
            case "stocks":                  state.stocksGroupedAssetHoldings    = grouped
            case "cash":                    state.cashGroupedAssetHoldings      = grouped
            case "real_estate", "realEstate": state.realEstateGroupedAssetHoldings = grouped
            case "retirement":              state.retirementGroupedAssetHoldings = grouped
            default: break
            }
        }

        return state
    }

    // MARK: - Private

    /// Convert a flat list of API grouped holdings into the legacy
    /// `GroupedAssetHolding` shape.
    ///
    /// Outer key: holding name (acts as a pseudo-account label until Phase 4).
    /// Inner key: symbol if available, otherwise name.
    private static func makeGroupedHolding(from holdings: [APIGroupedHolding]) -> GroupedAssetHolding {
        var result: GroupedAssetHolding = [:]
        for holding in holdings {
            let outerKey = holding.name
            let innerKey = holding.symbol ?? holding.name
            let assetHolding = AssetHolding(
                quantity: holding.quantity,
                totalValue: holding.currentValue
            )
            result[outerKey, default: [:]][innerKey] = assetHolding
        }
        return result
    }
}
