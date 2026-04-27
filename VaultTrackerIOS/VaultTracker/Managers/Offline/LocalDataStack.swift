//
//  LocalDataStack.swift
//  VaultTracker
//
//  One SwiftData `ModelContainer` and shared services for local cache, sync, and reachability
//  in the authenticated app shell. Holds `NetworkMonitoring`, cache + pending stores,
//  `OfflineSyncManager`, and a lazily built `DataRepository` (reused for the life of the object).
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class LocalDataStack: ObservableObject {
    let modelContainer: ModelContainer
    let networkMonitor: NWPathNetworkMonitor
    let cache: CachedDataStore
    let pendingStore: PendingTransactionStore
    let syncManager: OfflineSyncManager
    private var repositoryCache: DataRepository?

    init(
        dataService: DataServiceProtocol = DataService.shared,
        currentUserId: @escaping () -> String? = { nil }
    ) throws {
        self.modelContainer = try OfflinePersistence.makeModelContainer(inMemory: false)
        let context = ModelContext(modelContainer)
        self.cache = CachedDataStore(modelContext: context)
        self.pendingStore = PendingTransactionStore(modelContext: context)
        self.networkMonitor = NWPathNetworkMonitor()
        self.syncManager = OfflineSyncManager(
            dataService: dataService,
            pendingStore: pendingStore,
            network: networkMonitor,
            currentUserId: currentUserId
        )
    }

    /// Single shared repository for Home; the `userId` closure is evaluated on each read/write.
    func dataRepository(
        dataService: DataServiceProtocol = DataService.shared,
        api: APIServiceProtocol = APIService.shared,
        currentUserId: @escaping () -> String?
    ) -> DataRepository {
        if let repositoryCache { return repositoryCache }
        let repo = DataRepository(
            dataService: dataService,
            api: api,
            network: networkMonitor,
            cache: cache,
            syncManager: syncManager,
            currentUserId: currentUserId
        )
        repositoryCache = repo
        return repo
    }
}
