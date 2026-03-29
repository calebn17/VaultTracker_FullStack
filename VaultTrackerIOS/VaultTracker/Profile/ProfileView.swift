//
//  ProfileView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack {
            Spacer()
            Text("Welcome, \(authManager.user?.displayName ?? "User")!")
                .font(.title2.weight(.semibold))
                .foregroundStyle(VTColors.textPrimary)
                .padding()

            Button {
                do {
                    try authManager.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
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
            .padding()
            .accessibilityIdentifier("signOutButton")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VTColors.background.ignoresSafeArea())
        .navigationTitle("Profile")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
