//
//  FIREViewModelTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

@Suite("FIREViewModel", .serialized)
@MainActor
struct FIREViewModelTests {

    @Test func loadWhenSoloFetchesProfileAndProjection() async {
        let mock = MockDataService()
        let vm = FIREViewModel(dataService: mock)
        await vm.load()
        #expect(!vm.isInHousehold)
        #expect(vm.errorMessage == nil)
        #expect(mock.fetchHouseholdCallCount == 1)
        #expect(mock.fetchFIREProfileCallCount == 1)
        #expect(mock.fetchFIREProjectionCallCount == 1)
        #expect(mock.fetchHouseholdFIREProfileCallCount == 0)
        #expect(vm.projection != nil)
    }

    @Test func loadWhenInHouseholdFetchesHouseholdFIREOnly() async {
        let mock = MockDataService()
        mock.householdStub = mock.createHouseholdStub
        let vm = FIREViewModel(dataService: mock)
        await vm.load()
        #expect(vm.isInHousehold)
        #expect(vm.errorMessage == nil)
        #expect(mock.fetchHouseholdCallCount == 1)
        #expect(mock.fetchHouseholdFIREProfileCallCount == 1)
        #expect(mock.fetchFIREProfileCallCount == 0)
        #expect(mock.fetchFIREProjectionCallCount == 0)
        #expect(vm.projection == nil)
    }

    @Test func saveWhenSoloUpdatesPersonalAndRefetchesProjection() async {
        let mock = MockDataService()
        let vm = FIREViewModel(dataService: mock)
        await vm.load()
        #expect(mock.updateFIREProfileCallCount == 0)

        vm.currentAge = "40"
        vm.annualIncome = "120000"
        vm.annualExpenses = "60000"
        vm.targetRetirementAge = "62"

        await vm.save()
        #expect(mock.updateFIREProfileCallCount == 1)
        #expect(mock.lastFIREProfileInput?.currentAge == 40)
        #expect(mock.lastFIREProfileInput?.targetRetirementAge == 62)
        #expect(mock.updateHouseholdFIREProfileCallCount == 0)
        // load + save triggers second projection fetch
        #expect(mock.fetchFIREProjectionCallCount == 2)
    }

    @Test func saveWhenInHouseholdUpdatesSharedProfileOnly() async {
        let mock = MockDataService()
        mock.householdStub = mock.createHouseholdStub
        let vm = FIREViewModel(dataService: mock)
        await vm.load()
        #expect(mock.fetchFIREProjectionCallCount == 0)

        await vm.save()
        #expect(mock.updateHouseholdFIREProfileCallCount == 1)
        #expect(mock.updateFIREProfileCallCount == 0)
        #expect(mock.fetchFIREProjectionCallCount == 0)
    }

    @Test func saveWithTrimmedInputsNormalizesAndSendsPayload() async {
        let mock = MockDataService()
        let vm = FIREViewModel(dataService: mock)
        await vm.load()

        vm.currentAge = " 40 "
        vm.annualIncome = " 120,000.5 "
        vm.annualExpenses = " 60,000 "
        vm.targetRetirementAge = " 61 "

        await vm.save()

        #expect(vm.errorMessage == nil)
        #expect(mock.updateFIREProfileCallCount == 1)
        #expect(mock.lastFIREProfileInput?.currentAge == 40)
        #expect(mock.lastFIREProfileInput?.annualIncome == 120_000.5)
        #expect(mock.lastFIREProfileInput?.annualExpenses == 60_000)
        #expect(mock.lastFIREProfileInput?.targetRetirementAge == 61)
    }

    @Test func saveWithMalformedIncomeSkipsUpdateAndShowsValidationError() async {
        let mock = MockDataService()
        let vm = FIREViewModel(dataService: mock)
        await vm.load()

        vm.currentAge = "40"
        vm.annualIncome = "'; DROP TABLE fire_profiles; --"
        vm.annualExpenses = "50000"
        vm.targetRetirementAge = "62"

        await vm.save()

        #expect(mock.updateFIREProfileCallCount == 0)
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage?.contains("Annual income") == true)
    }

    @Test func saveWithTargetAgeNotGreaterThanCurrentAgeSkipsUpdate() async {
        let mock = MockDataService()
        let vm = FIREViewModel(dataService: mock)
        await vm.load()

        vm.currentAge = "45"
        vm.annualIncome = "120000"
        vm.annualExpenses = "65000"
        vm.targetRetirementAge = "45"

        await vm.save()

        #expect(mock.updateFIREProfileCallCount == 0)
        #expect(vm.errorMessage?.contains("Target retirement age") == true)
    }
}
