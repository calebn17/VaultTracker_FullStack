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
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("analyticsErrorRow")
                }
            }

            if let p = viewModel.performance {
                Section("Performance") {
                    LabeledContent("Gain / loss") {
                        Text(p.totalGainLoss.currencyFormat())
                    }
                    LabeledContent("Gain / loss %") {
                        Text("\(p.totalGainLossPercent.twoDecimalString)%")
                    }
                    LabeledContent("Cost basis") {
                        Text(p.costBasis.currencyFormat())
                    }
                    LabeledContent("Current value") {
                        Text(p.currentValue.currencyFormat())
                    }
                }
                .accessibilityIdentifier("analyticsPerformanceSection")
            }

            Section("Allocation") {
                ForEach(viewModel.allocationEntries, id: \.key) { row in
                    HStack {
                        Text(row.key)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(row.entry.value.currencyFormat())
                            Text("\(row.entry.percentage.twoDecimalString)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .accessibilityIdentifier("analyticsAllocationSection")
        }
        .accessibilityIdentifier("analyticsScreen")
        .navigationTitle("Analytics")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
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
}

#Preview {
    NavigationView {
        AnalyticsView()
    }
}
