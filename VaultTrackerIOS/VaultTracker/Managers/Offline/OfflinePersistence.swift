//
//  OfflinePersistence.swift
//  VaultTracker
//
//  Shared SwiftData schema for offline queue + read cache. API payload shapes
//  live in encoded Data; migrate deliberately when those types change.

import Foundation
import SwiftData

enum OfflinePersistence {

    /// All `@Model` types registered for the offline store.
    static let schema = Schema([
        PendingTransaction.self,
        CachedPersonalDashboard.self,
        CachedHouseholdDashboard.self,
        CachedNetWorthHistory.self,
        CachedTransaction.self
    ])

    static func makeModelContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
