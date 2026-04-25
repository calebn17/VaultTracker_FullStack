//
//  FIREViewModel.swift
//  VaultTracker
//
//  Personal mode: load personal FIRE profile + projection. Household mode: shared profile only;
//  combined projection is not available (matches web + API).
//

import Foundation

@MainActor
final class FIREViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    /// True when `GET /households/me` resolves to a household.
    @Published var isInHousehold = false
    /// Only set in personal mode after a successful projection fetch.
    @Published var projection: APIFIREProjectionResponse?

    @Published var currentAge = "30"
    @Published var annualIncome = "0"
    @Published var annualExpenses = "0"
    @Published var targetRetirementAge = ""

    private var dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        projection = nil
        defer { isLoading = false }
        do {
            let household = try await dataService.fetchHousehold()
            isInHousehold = household != nil
            if isInHousehold {
                let profile = try await dataService.fetchHouseholdFIREProfile()
                applyProfile(profile)
            } else {
                let profile = try await dataService.fetchFIREProfile()
                applyProfile(profile)
                projection = try await dataService.fetchFIREProjection()
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let input = buildInput()
            if isInHousehold {
                let profile = try await dataService.updateHouseholdFIREProfile(input)
                applyProfile(profile)
            } else {
                let profile = try await dataService.updateFIREProfile(input)
                applyProfile(profile)
                projection = try await dataService.fetchFIREProjection()
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyProfile(_ profile: APIFIREProfileResponse) {
        currentAge = String(profile.currentAge)
        annualIncome = fireNumberString(profile.annualIncome)
        annualExpenses = fireNumberString(profile.annualExpenses)
        if let target = profile.targetRetirementAge {
            targetRetirementAge = String(target)
        } else {
            targetRetirementAge = ""
        }
    }

    private func fireNumberString(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(value)
    }

    private func buildInput() -> APIFIREProfileInput {
        let age = Int(currentAge.trimmingCharacters(in: .whitespaces)) ?? 30
        let income = parseDouble(annualIncome)
        let expenses = parseDouble(annualExpenses)
        let targetStr = targetRetirementAge.trimmingCharacters(in: .whitespaces)
        let targetAge: Int? = targetStr.isEmpty ? nil : Int(targetStr)
        return APIFIREProfileInput(
            currentAge: age,
            annualIncome: income,
            annualExpenses: expenses,
            targetRetirementAge: targetAge
        )
    }

    private func parseDouble(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Double(trimmed.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}
