//
//  NWPathNetworkMonitor.swift
//  VaultTracker
//

import Combine
import Foundation
import Network

/// Retains a path monitor; `cancel()` is called in `deinit` (thread-safe) so the outer
/// `NWPathNetworkMonitor` does not need a nonisolated `deinit` that touches MainActor state.
private final class NWPathMonitorBox {
    let monitor: NWPathMonitor

    init() {
        monitor = NWPathMonitor()
    }

    deinit {
        monitor.cancel()
    }
}

/// Production `NetworkMonitoring` implementation. The monitor runs until this object is deallocated
/// (e.g. for a per-session instance created when the user is authenticated).
@MainActor
final class NWPathNetworkMonitor: ObservableObject, NetworkMonitoring {
    @Published private(set) var isConnected: Bool

    private let box = NWPathMonitorBox()
    private let queue = DispatchQueue(label: "com.vaulttracker.nwpath")
    private var reachabilityHandler: (() -> Void)?

    init() {
        self.isConnected = false
        let mon = box.monitor
        mon.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = path.status == .satisfied
                self.reachabilityHandler?()
            }
        }
        mon.start(queue: queue)
        isConnected = mon.currentPath.status == .satisfied
    }

    func setReachabilityHandler(_ handler: (() -> Void)?) {
        reachabilityHandler = handler
    }
}
