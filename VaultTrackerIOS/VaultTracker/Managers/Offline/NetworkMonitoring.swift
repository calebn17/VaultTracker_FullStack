//
//  NetworkMonitoring.swift
//  VaultTracker
//

import Foundation

/// Abstraction for reachability. Unit tests use a fake; the app uses `NWPathNetworkMonitor`
/// (wraps `NWPathMonitor`). Do not unit test against a real `NWPathMonitor` instance.
@MainActor
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
    /// Invoked on the main actor when connectivity may have changed.
    /// Used by `OfflineSyncManager` to auto-drain the queue (pending items only) when
    /// the path becomes satisfied. Install once; replace with `nil` to stop callbacks.
    func setReachabilityHandler(_ handler: (() -> Void)?)
}
