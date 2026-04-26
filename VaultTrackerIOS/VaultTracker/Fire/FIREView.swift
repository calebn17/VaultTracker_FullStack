//
//  FIREView.swift
//  VaultTracker
//

import SwiftUI

struct FIREView: View {
    @StateObject private var viewModel = FIREViewModel()

    var body: some View {
        List {
            errorSection

            if viewModel.isInHousehold {
                Section {
                    Text(
                        "Shared household FIRE profile. Any member can edit these inputs. "
                            + "Multi-year projection for combined household wealth is not available in this release."
                    )
                    .font(VTFonts.body)
                    .foregroundStyle(VTColors.textSubdued)
                    .listRowBackground(VTColors.surface)
                    .accessibilityIdentifier("fireHouseholdBanner")
                } header: {
                    sectionHeader("Household")
                }
            }

            if !viewModel.isInHousehold, let projection = viewModel.projection {
                projectionSection(projection)
            } else if !viewModel.isInHousehold, viewModel.projection == nil, !viewModel.isLoading {
                Section {
                    Text("Save your inputs to run a projection.")
                        .font(VTFonts.body)
                        .foregroundStyle(VTColors.textSubdued)
                        .listRowBackground(VTColors.surface)
                } header: {
                    sectionHeader("Projection")
                }
            }

            inputsSection

            Section {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(VTColors.primary)
                        } else {
                            Text("Save")
                                .font(VTFonts.body)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isSaving || viewModel.isLoading)
                .listRowBackground(VTColors.surface)
                .accessibilityIdentifier("fireSaveButton")
            }
        }
        .scrollContentBackground(.hidden)
        .background(VTColors.background)
        .navigationTitle("FIRE")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView()
                        .tint(VTColors.primary)
                }
                .ignoresSafeArea()
                .accessibilityIdentifier("fireLoadingOverlay")
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                Text(error)
                    .font(VTFonts.body)
                    .foregroundStyle(VTColors.error)
                    .listRowBackground(VTColors.error.opacity(0.15))
                    .accessibilityIdentifier("fireErrorRow")
            }
        }
    }

    private func projectionSection(_ projection: APIFIREProjectionResponse) -> some View {
        Section {
            LabeledContent("Status") {
                Text(projection.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)
            }
            .listRowBackground(VTColors.surface)

            fireTargetRow(title: "Lean FIRE", tier: projection.fireTargets.leanFire)
            fireTargetRow(title: "FIRE", tier: projection.fireTargets.fire)
            fireTargetRow(title: "Fat FIRE", tier: projection.fireTargets.fatFire)

            if let months = projection.monthlyBreakdown.monthsToFire {
                LabeledContent("Months to FIRE") {
                    Text("\(months)")
                        .font(VTFonts.monoBody)
                        .foregroundStyle(VTColors.textPrimary)
                }
                .listRowBackground(VTColors.surface)
            }

            LabeledContent("Monthly surplus") {
                Text(projection.monthlyBreakdown.monthlySurplus.currencyFormat())
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)
            }
            .listRowBackground(VTColors.surface)
        } header: {
            sectionHeader("Projection")
        }
        .accessibilityIdentifier("fireProjectionSection")
    }

    private func fireTargetRow(title: String, tier: APIFIRETargetTier) -> some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(tier.targetAmount.currencyFormat())
                    .font(VTFonts.monoBody)
                    .foregroundStyle(VTColors.textPrimary)
                if let years = tier.yearsToTarget {
                    Text("~\(years) years")
                        .font(VTFonts.caption)
                        .foregroundStyle(VTColors.textSubdued)
                }
            }
        }
        .listRowBackground(VTColors.surface)
    }

    private var inputsSection: some View {
        Section {
            TextField("Current age", text: $viewModel.currentAge)
                .keyboardType(.numberPad)
                .font(VTFonts.body)
                .foregroundStyle(VTColors.textPrimary)
                .listRowBackground(VTColors.surface)
                .accessibilityIdentifier("fireInputCurrentAge")

            TextField("Annual income", text: $viewModel.annualIncome)
                .keyboardType(.decimalPad)
                .font(VTFonts.body)
                .foregroundStyle(VTColors.textPrimary)
                .listRowBackground(VTColors.surface)
                .accessibilityIdentifier("fireInputAnnualIncome")

            TextField("Annual expenses", text: $viewModel.annualExpenses)
                .keyboardType(.decimalPad)
                .font(VTFonts.body)
                .foregroundStyle(VTColors.textPrimary)
                .listRowBackground(VTColors.surface)
                .accessibilityIdentifier("fireInputAnnualExpenses")

            TextField("Target retirement age (optional)", text: $viewModel.targetRetirementAge)
                .keyboardType(.numberPad)
                .font(VTFonts.body)
                .foregroundStyle(VTColors.textPrimary)
                .listRowBackground(VTColors.surface)
                .accessibilityIdentifier("fireInputTargetRetirementAge")
        } header: {
            sectionHeader("Assumptions")
        } footer: {
            Text("Simulations use your saved inputs plus live portfolio totals (same as the dashboard).")
                .font(VTFonts.caption)
                .foregroundStyle(VTColors.textSubdued)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VTFonts.sectionHeader)
            .foregroundStyle(VTColors.textSubdued)
            .textCase(.uppercase)
    }
}

#Preview {
    NavigationView {
        FIREView()
    }
}
