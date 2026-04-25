//
//  HouseholdSettingsViewModel.swift
//  VaultTracker
//

import Foundation

@MainActor
final class HouseholdSettingsViewModel: ObservableObject {
    @Published var household: Household?
    @Published var inviteCode: HouseholdInviteCode?
    @Published var joinCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = DataService.shared) {
        self.dataService = dataService
    }

    func loadHousehold() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            household = try await dataService.fetchHousehold()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHousehold() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            household = try await dataService.createHousehold()
            inviteCode = nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateInviteCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            inviteCode = try await dataService.generateInviteCode()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinHousehold() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "Enter an invite code."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            household = try await dataService.joinHousehold(code: code)
            joinCode = ""
            inviteCode = nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveHousehold() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await dataService.leaveHousehold()
            household = nil
            inviteCode = nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
