//
//  HouseholdSettingsViewModelTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

@Suite("HouseholdSettingsViewModel", .serialized)
@MainActor
struct HouseholdSettingsViewModelTests {

    @Test func loadHouseholdPopulatesState() async {
        let mock = MockDataService()
        let h = Household(
            id: "h1",
            members: [HouseholdMember(userId: "u1", email: "e@e.com")],
            createdAt: Date(timeIntervalSince1970: 0)
        )
        mock.householdStub = h
        let vm = HouseholdSettingsViewModel(dataService: mock)
        await vm.loadHousehold()
        #expect(vm.household?.id == "h1")
        #expect(mock.fetchHouseholdCallCount == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test func createHouseholdUpdatesState() async {
        let mock = MockDataService()
        let vm = HouseholdSettingsViewModel(dataService: mock)
        await vm.createHousehold()
        #expect(vm.household != nil)
        #expect(mock.createHouseholdCallCount == 1)
    }
}
