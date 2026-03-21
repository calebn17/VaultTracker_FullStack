
//
//  NetWorthChartView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import SwiftUI
import Charts

struct NetWorthChartView: View {
    var snapshots: [NetWorthSnapshot]

    var body: some View {
        Chart(snapshots) { snapshot in
            LineMark(
                x: .value("Date", snapshot.date),
                y: .value("Net Worth", snapshot.value)
            )
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", snapshot.date),
                y: .value("Net Worth", snapshot.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.4), .clear]), startPoint: .top, endPoint: .bottom))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 200)
        .accessibilityIdentifier("netWorthChartContent")
    }
}
