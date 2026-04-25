//
//  ProfileView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var householdSettingsViewModel = HouseholdSettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome, \(authManager.user?.displayName ?? "User")!")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(VTColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("profileWelcomeText")

                HouseholdSettingsView(viewModel: householdSettingsViewModel)

                Spacer(minLength: 24)

                Button {
                    do {
                        try authManager.signOut()
                    } catch {
                        VTLog.shared.error("Error signing out", error: error, category: .ui)
                    }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VTColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VTColors.error)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 8)
                .accessibilityIdentifier("signOutButton")
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VTColors.background.ignoresSafeArea())
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthManager())
    }
}
