//
//  AnalyticsView.swift
//  VaultTracker
//

import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(VTFonts.body)
                        .foregroundStyle(VTColors.error)
                        .listRowBackground(VTColors.error.opacity(0.15))
                        .accessibilityIdentifier("analyticsErrorRow")
                }
            }

            if let performance = viewModel.performance {
                Section {
                    LabeledContent {
                        Text(performance.totalGainLoss.currencyFormat())
                            .font(VTFonts.monoBody)
                            .foregroundStyle(gainLossForeground(performance.totalGainLoss))
                    } label: {
                        Text("Gain / loss")
                            .foregroundStyle(VTColors.textSubdued)
                    }
                    .listRowBackground(VTColors.surface)

                    LabeledContent {
                        Text("\(performance.totalGainLossPercent.twoDecimalString)%")
                            .font(VTFonts.monoBody)
                            .foregroundStyle(gainLossForeground(performance.totalGainLossPercent))
                    } label: {
                        Text("Gain / loss %")
                            .foregroundStyle(VTColors.textSubdued)
                    }
                    .listRowBackground(VTColors.surface)

                    LabeledContent {
                        Text(performance.costBasis.currencyFormat())
                            .font(VTFonts.monoBody)
                            .foregroundStyle(VTColors.textPrimary)
                    } label: {
                        Text("Cost basis")
                            .foregroundStyle(VTColors.textSubdued)
                    }
                    .listRowBackground(VTColors.surface)

                    LabeledContent {
                        Text(performance.currentValue.currencyFormat())
                            .font(VTFonts.monoBody)
                            .foregroundStyle(VTColors.textPrimary)
                    } label: {
                        Text("Current value")
                            .foregroundStyle(VTColors.textSubdued)
                    }
                    .listRowBackground(VTColors.surface)
                } header: {
                    Text("Performance")
                        .font(VTFonts.sectionHeader)
                        .foregroundStyle(VTColors.textSubdued)
                        .textCase(.uppercase)
                        .accessibilityIdentifier("analyticsPerformanceSection")
                }
            }

            Section {
                ForEach(viewModel.allocationEntries, id: \.key) { row in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(allocationDotColor(for: row.key))
                            .frame(width: 8, height: 8)

                        Text(allocationRowTitle(for: row.key))
                            .font(VTFonts.body)
                            .foregroundStyle(VTColors.textPrimary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(row.entry.value.currencyFormat())
                                .font(VTFonts.monoBody)
                                .foregroundStyle(VTColors.textPrimary)
                            Text("\(row.entry.percentage.twoDecimalString)%")
                                .font(VTFonts.monoCaption)
                                .foregroundStyle(VTColors.textSubdued)
                        }
                    }
                    .listRowBackground(VTColors.surface)
                }
            } header: {
                Text("Allocation")
                    .font(VTFonts.sectionHeader)
                    .foregroundStyle(VTColors.textSubdued)
                    .textCase(.uppercase)
                    .accessibilityIdentifier("analyticsAllocationSection")
            }
        }
        .accessibilityIdentifier("analyticsScreen")
        .scrollContentBackground(.hidden)
        .background(VTColors.background)
        .navigationTitle("Analytics")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .tint(VTColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VTColors.background.opacity(0.7))
                    .accessibilityIdentifier("analyticsLoadingOverlay")
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func gainLossForeground(_ value: Double) -> Color {
        if value > 0 { return VTColors.primary }
        if value < 0 { return VTColors.error }
        return VTColors.textSubdued
    }

    private func allocationDotColor(for key: String) -> Color {
        switch key {
        case "crypto": return VTColors.categoryAccent(.crypto)
        case "stocks": return VTColors.categoryAccent(.stocks)
        case "cash": return VTColors.categoryAccent(.cash)
        case "realEstate": return VTColors.categoryAccent(.realEstate)
        case "retirement": return VTColors.categoryAccent(.retirement)
        default: return VTColors.textSubdued
        }
    }

    private func allocationRowTitle(for key: String) -> String {
        switch key {
        case "crypto": return "Crypto"
        case "stocks": return "Stocks"
        case "cash": return "Cash"
        case "realEstate": return "Real Estate"
        case "retirement": return "Retirement"
        default:
            return key
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}

#Preview {
    NavigationView {
        AnalyticsView()
    }
}
