//
//  HouseholdSettingsView.swift
//  VaultTracker
//
//  Household create / join / invite / leave. Uses stable accessibility ids for UI tests.
//

import SwiftUI
import UIKit

struct HouseholdSettingsView: View {
    @ObservedObject var viewModel: HouseholdSettingsViewModel
    @State private var showLeaveConfirmation = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Household")
                .font(VTFonts.sectionHeader)
                .foregroundStyle(VTColors.textSubdued)
                .accessibilityIdentifier("householdSettingsHeader")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(VTFonts.body)
                    .foregroundStyle(VTColors.error)
                    .accessibilityIdentifier("householdSettingsError")
            }

            if let household = viewModel.household {
                inHouseholdContent(household: household)
            } else {
                notInHouseholdContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await viewModel.loadHousehold()
        }
    }

    private var notInHouseholdContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create a household for two people to share a combined view, or join with a code from your partner.")
                .font(VTFonts.caption)
                .foregroundStyle(VTColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await viewModel.createHousehold() }
            } label: {
                Text("Create Household")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VTPrimaryButtonStyle())
            .accessibilityIdentifier("householdCreateButton")

            TextField("Invite code", text: $viewModel.joinCode)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("householdJoinCodeField")

            Button {
                Task { await viewModel.joinHousehold() }
            } label: {
                Text("Join Household")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VTPrimaryButtonStyle())
            .accessibilityIdentifier("householdJoinButton")
        }
    }

    @ViewBuilder
    private func inHouseholdContent(household: Household) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(VTFonts.body)
                .fontWeight(.semibold)
                .foregroundStyle(VTColors.textPrimary)
            memberList(household)

            Button {
                Task { await viewModel.generateInviteCode() }
            } label: {
                Text("Generate invite code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VTPrimaryButtonStyle())
            .accessibilityIdentifier("householdGenerateCodeButton")

            if let invite = viewModel.inviteCode {
                inviteCodeCard(invite)
            }

            leaveHouseholdButton
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Copied")
                    .font(VTFonts.caption)
                    .padding(8)
                    .background(VTColors.surface)
                    .clipShape(Capsule())
                    .transition(.opacity)
            }
        }
        .onChange(of: showCopiedToast) { _, isShown in
            if isShown {
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showCopiedToast = false
                }
            }
        }
    }

    private func memberList(_ household: Household) -> some View {
        ForEach(household.members, id: \.userId) { member in
            HStack {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(VTColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.email ?? "Household member")
                        .font(VTFonts.body)
                        .foregroundStyle(VTColors.textPrimary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("householdMember_\(member.userId)")
        }
        .accessibilityIdentifier("householdMembersList")
    }

    private func inviteCodeCard(_ invite: HouseholdInviteCode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code: \(invite.code)")
                .font(VTFonts.monoBody)
                .foregroundStyle(VTColors.textPrimary)
                .accessibilityIdentifier("householdInviteCodeLabel")
            Text("Expires: \(invite.expiresAt, style: .relative) from now")
                .font(VTFonts.caption)
                .foregroundStyle(VTColors.textSubdued)
                .accessibilityIdentifier("householdInviteCodeExpiryText")
            Button {
                UIPasteboard.general.string = invite.code
                showCopiedToast = true
            } label: {
                Text("Copy code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VTPrimaryButtonStyle())
            .accessibilityIdentifier("householdCopyInviteCodeButton")
        }
        .padding()
        .background(VTColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var leaveHouseholdButton: some View {
        Button("Leave household", role: .destructive) {
            showLeaveConfirmation = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("householdLeaveButton")
        .confirmationDialog(
            "Leave this household?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { await viewModel.leaveHousehold() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can create or join another household later.")
        }
    }
}

#Preview {
    HouseholdSettingsView(viewModel: HouseholdSettingsViewModel())
        .padding()
        .background(VTColors.background)
}
