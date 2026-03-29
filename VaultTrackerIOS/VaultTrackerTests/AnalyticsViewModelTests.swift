//
//  AnalyticsViewModelTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("AnalyticsViewModel", .serialized)
@MainActor
struct AnalyticsViewModelTests {

    let mockService: MockDataService
    let viewModel: AnalyticsViewModel

    init() throws {
        mockService = MockDataService()
        viewModel = AnalyticsViewModel(dataService: mockService)
    }

    // MARK: - Happy Path

    @Test func loadSetsAllocationEntriesSortedAlphabetically() async {
        mockService.analyticsStub = APIAnalyticsResponse(
            allocation: [
                "stocks": APIAllocationEntry(value: 30_000, percentage: 30),
                "crypto": APIAllocationEntry(value: 60_000, percentage: 60),
                "cash":   APIAllocationEntry(value: 10_000, percentage: 10)
            ],
            performance: APIPerformanceBlock(totalGainLoss: 0, totalGainLossPercent: 0, costBasis: 0, currentValue: 0)
        )

        await viewModel.load()

        #expect(viewModel.allocationEntries.count == 3)
        #expect(viewModel.allocationEntries[0].key == "cash")
        #expect(viewModel.allocationEntries[0].entry.value == 10_000)
        #expect(viewModel.allocationEntries[1].key == "crypto")
        #expect(viewModel.allocationEntries[1].entry.value == 60_000)
        #expect(viewModel.allocationEntries[2].key == "stocks")
        #expect(viewModel.allocationEntries[2].entry.value == 30_000)
    }

    @Test func loadSetsPerformanceBlock() async {
        mockService.analyticsStub = APIAnalyticsResponse(
            allocation: [:],
            performance: APIPerformanceBlock(
                totalGainLoss: 12_345,
                totalGainLossPercent: 14.1,
                costBasis: 87_655,
                currentValue: 100_000
            )
        )

        await viewModel.load()

        #expect(viewModel.performance?.totalGainLoss == 12_345)
        #expect(viewModel.performance?.costBasis == 87_655)
        #expect(viewModel.performance?.currentValue == 100_000)
    }

    @Test func loadClearsLoadingStateOnSuccess() async {
        await viewModel.load()

        #expect(viewModel.isLoading == false)
    }

    @Test func loadClearsErrorMessageOnSuccess() async {
        viewModel.errorMessage = "stale error from previous load"
        mockService.analyticsStub = APIAnalyticsResponse(
            allocation: ["cash": APIAllocationEntry(value: 1_000, percentage: 100)],
            performance: APIPerformanceBlock(totalGainLoss: 0, totalGainLossPercent: 0, costBasis: 1_000, currentValue: 1_000)
        )

        await viewModel.load()

        #expect(viewModel.errorMessage == nil)
    }

    @Test func loadCallsFetchAnalyticsExactlyOnce() async {
        await viewModel.load()
        #expect(mockService.fetchAnalyticsCallCount == 1)

        await viewModel.load()
        #expect(mockService.fetchAnalyticsCallCount == 2)
    }

    @Test func loadWithEmptyAllocationProducesEmptyEntries() async {
        mockService.analyticsStub = APIAnalyticsResponse(
            allocation: [:],
            performance: APIPerformanceBlock(totalGainLoss: 0, totalGainLossPercent: 0, costBasis: 0, currentValue: 0)
        )

        await viewModel.load()

        #expect(viewModel.allocationEntries.isEmpty)
    }

    // MARK: - Error Paths

    @Test func loadSetsErrorMessageOnAPIError() async {
        mockService.analyticsError = APIError.serverError(500)

        await viewModel.load()

        #expect(viewModel.errorMessage == "A server error occurred (code 500). Please try again later.")
        #expect(viewModel.isLoading == false)
    }

    @Test func loadSetsErrorMessageOnGenericError() async {
        mockService.analyticsError = URLError(.notConnectedToInternet)

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage!.isEmpty == false)
        #expect(viewModel.isLoading == false)
    }

    @Test func loadRetainsPreviousDataOnError() async {
        // First load succeeds — populates state
        mockService.analyticsStub = APIAnalyticsResponse(
            allocation: ["crypto": APIAllocationEntry(value: 50_000, percentage: 100)],
            performance: APIPerformanceBlock(totalGainLoss: 5_000, totalGainLossPercent: 10, costBasis: 45_000, currentValue: 50_000)
        )
        await viewModel.load()
        #expect(viewModel.allocationEntries.count == 1)

        // Second load fails — data should be retained (not wiped)
        mockService.analyticsError = APIError.serverError(503)
        await viewModel.load()

        #expect(viewModel.allocationEntries.count == 1)
        #expect(viewModel.allocationEntries[0].key == "crypto")
        #expect(viewModel.errorMessage != nil)
    }
}
