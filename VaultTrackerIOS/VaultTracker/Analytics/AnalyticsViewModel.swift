//
//  AnalyticsViewModel.swift
//  VaultTracker
//

import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var allocationEntries: [(key: String, entry: APIAllocationEntry)] = []
    @Published var performance: APIPerformanceBlock?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let analytics = try await dataService.fetchAnalytics()
            allocationEntries = analytics.allocation
                .map { (key: $0.key, entry: $0.value) }
                .sorted { $0.key < $1.key }
            performance = analytics.performance
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
