//
//  DashboardMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

// Converts an APIDashboardResponse into a HomeViewState ready for the UI.
// Maps the API's groupedHoldings dictionary (keys: "crypto", "stocks", "cash",
// "realEstate", "retirement") to the corresponding holdings arrays on the view state.
// Both "real_estate" and "realEstate" are accepted to guard against future backend
// key changes, but the canonical form that must match the iOS category strings is
// camelCase "realEstate".

import Foundation

enum DashboardMapper {

    static func toViewState(_ response: APIDashboardResponse) -> HomeViewState {
        var state = HomeViewState()

        state.totalNetworthValue   = response.totalNetWorth
        state.cryptoTotalValue     = response.categoryTotals.crypto
        state.stocksTotalValue     = response.categoryTotals.stocks
        state.cashTotalValue       = response.categoryTotals.cash
        state.realEstateTotalValue = response.categoryTotals.realEstate
        state.retirementTotalValue = response.categoryTotals.retirement

        for (category, holdings) in response.groupedHoldings {
            switch category {
            case "crypto":                      state.cryptoGroupedAssetHoldings     = holdings
            case "stocks":                      state.stocksGroupedAssetHoldings     = holdings
            case "cash":                        state.cashGroupedAssetHoldings       = holdings
            case "real_estate", "realEstate":   state.realEstateGroupedAssetHoldings = holdings
            case "retirement":                  state.retirementGroupedAssetHoldings = holdings
            default: break
            }
        }

        return state
    }
}
