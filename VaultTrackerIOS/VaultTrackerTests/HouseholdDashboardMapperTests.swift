//
//  HouseholdDashboardMapperTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

@Suite("HouseholdDashboardMapper", .serialized)
struct HouseholdDashboardMapperTests {

    @Test func mapsToViewState() throws {
        let btc = APIGroupedHolding(
            id: "a1",
            name: "Bitcoin",
            symbol: "BTC",
            quantity: 1,
            currentValue: 10_000
        )
        let response = APIHouseholdDashboardResponse(
            householdId: "hh-1",
            totalNetWorth: 20_000,
            categoryTotals: APICategoryTotals(crypto: 20_000),
            members: [
                APIHouseholdMemberDashboard(
                    userId: "m1",
                    email: "x@y.com",
                    totalNetWorth: 20_000,
                    categoryTotals: APICategoryTotals(crypto: 20_000),
                    groupedHoldings: ["crypto": [btc]]
                )
            ]
        )
        let vs = HouseholdDashboardMapper.toViewState(response)
        #expect(vs.totalNetWorth == 20_000)
        #expect(vs.members.count == 1)
        #expect(vs.members[0].userId == "m1")
        #expect(vs.members[0].groupedHoldings(for: .crypto).count == 1)
    }
}
