//
//  OfflineBanner.swift
//  VaultTracker
//

import SwiftUI

/// Thin status strip under the status bar: offline, pending outbox, or failed sync; manual retry when
/// there are failures and the user is online.
struct OfflineBanner: View {
    @ObservedObject var network: NWPathNetworkMonitor
    @ObservedObject var sync: OfflineSyncManager
    @State private var showsFailedItems = false

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: iconName)
                        .foregroundColor(VTColors.textSubdued)
                    Text(message)
                        .font(VTFonts.caption)
                        .foregroundColor(VTColors.textSubdued)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if canRetry {
                        Button("Sync now") {
                            Task { await sync.syncNow(retryFailedItems: true) }
                        }
                        .font(VTFonts.caption)
                        .tint(VTColors.primary)
                    }
                    if !sync.failedItems.isEmpty {
                        Button(showsFailedItems ? "Hide" : "Details") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsFailedItems.toggle()
                            }
                        }
                        .font(VTFonts.caption)
                        .tint(VTColors.primary)
                    }
                }
                if showsFailedItems, !sync.failedItems.isEmpty {
                    failedItemsList
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VTColors.surface)
        } else {
            EmptyView()
        }
    }

    private var shouldShow: Bool {
        if !network.isConnected { return true }
        if sync.pendingCount > 0 { return true }
        if sync.failedCount > 0 { return true }
        if case .syncing = sync.syncStatus { return true }
        if case .failed = sync.syncStatus { return true }
        return false
    }

    private var message: String {
        if !network.isConnected { return "You're offline" }
        if case let .syncing(progress, total) = sync.syncStatus, total > 0 {
            return "Syncing… \(progress)/\(total)"
        }
        if sync.failedCount > 0 {
            return "\(sync.failedCount) transaction(s) could not be synced"
        }
        if sync.pendingCount > 0 {
            return "\(sync.pendingCount) change(s) waiting to upload"
        }
        if case let .failed(unsyncedCount) = sync.syncStatus, unsyncedCount > 0 {
            return "\(unsyncedCount) change(s) need attention"
        }
        return ""
    }

    private var iconName: String {
        if !network.isConnected { return "wifi.slash" }
        if sync.failedCount > 0 { return "exclamationmark.triangle" }
        return "arrow.triangle.2.circlepath"
    }

    private var canRetry: Bool { network.isConnected && sync.failedCount > 0 }

    private var failedItemsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sync.failedItems) { item in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(VTFonts.caption)
                            .foregroundColor(VTColors.textPrimary)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(VTFonts.caption)
                                .foregroundColor(VTColors.textSubdued)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Discard") {
                        try? sync.discardPending(id: item.id)
                    }
                    .font(VTFonts.caption)
                    .tint(VTColors.error)
                }
            }
        }
    }
}
