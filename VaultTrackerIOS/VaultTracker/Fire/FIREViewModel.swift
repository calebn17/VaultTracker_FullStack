//
//  FIREViewModel.swift
//  VaultTracker
//
//  Personal mode: load personal FIRE profile + projection. Household mode: shared profile only;
//  combined projection is not available (matches web + API).
//

import Foundation

private enum FIREInputValidationError: LocalizedError {
    case invalidCurrentAge
    case invalidAnnualIncome
    case invalidAnnualExpenses
    case invalidTargetRetirementAge
    case targetAgeMustExceedCurrentAge

    var errorDescription: String? {
        switch self {
        case .invalidCurrentAge:
            return "Current age must be a whole number between 18 and 100."
        case .invalidAnnualIncome:
            return "Annual income must be a valid non-negative number."
        case .invalidAnnualExpenses:
            return "Annual expenses must be a valid non-negative number."
        case .invalidTargetRetirementAge:
            return "Target retirement age must be a whole number between 19 and 100."
        case .targetAgeMustExceedCurrentAge:
            return "Target retirement age must be greater than current age."
        }
    }
}

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
            let input = try buildInput()
            if isInHousehold {
                let profile = try await dataService.updateHouseholdFIREProfile(input)
                applyProfile(profile)
            } else {
                let profile = try await dataService.updateFIREProfile(input)
                applyProfile(profile)
                projection = try await dataService.fetchFIREProjection()
            }
        } catch let error as FIREInputValidationError {
            errorMessage = error.errorDescription
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

    private func buildInput() throws -> APIFIREProfileInput {
        let age = try parseWholeNumber(
            currentAge,
            min: 18,
            max: 100,
            invalidError: .invalidCurrentAge
        )
        let income = try parseNonNegativeNumber(annualIncome, invalidError: .invalidAnnualIncome)
        let expenses = try parseNonNegativeNumber(annualExpenses, invalidError: .invalidAnnualExpenses)
        let targetAge = try parseOptionalWholeNumber(
            targetRetirementAge,
            min: 19,
            max: 100,
            invalidError: .invalidTargetRetirementAge
        )
        if let targetAge, targetAge <= age {
            throw FIREInputValidationError.targetAgeMustExceedCurrentAge
        }
        return APIFIREProfileInput(
            currentAge: age,
            annualIncome: income,
            annualExpenses: expenses,
            targetRetirementAge: targetAge
        )
    }

    private func parseWholeNumber(
        _ raw: String,
        min: Int,
        max: Int,
        invalidError: FIREInputValidationError
    ) throws -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
            throw invalidError
        }
        guard let value = Int(trimmed), value >= min, value <= max else {
            throw invalidError
        }
        return value
    }

    private func parseOptionalWholeNumber(
        _ raw: String,
        min: Int,
        max: Int,
        invalidError: FIREInputValidationError
    ) throws -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return try parseWholeNumber(trimmed, min: min, max: max, invalidError: invalidError)
    }

    private func parseNonNegativeNumber(
        _ raw: String,
        invalidError: FIREInputValidationError
    ) throws -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw invalidError
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard normalized.range(
            of: #"^[+]?(?:\d+(?:\.\d+)?|\.\d+)$"#,
            options: .regularExpression
        ) != nil else {
            throw invalidError
        }
        guard let value = Double(normalized), value.isFinite, value >= 0 else {
            throw invalidError
        }
        return value
    }
}
