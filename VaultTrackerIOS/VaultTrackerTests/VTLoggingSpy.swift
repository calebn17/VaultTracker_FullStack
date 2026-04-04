//
//  VTLoggingSpy.swift
//  VaultTrackerTests
//

import Foundation
@testable import VaultTracker

/// Captures log calls for assertions (production uses ``VTLogLive``).
final class VTLoggingSpy: VTLogging {

    struct Entry: Equatable {
        enum Level: Equatable {
            case info
            case warn
            case error
        }

        let level: Level
        let message: String
        let category: VTLogCategory
        /// Normalized for stable `#expect` comparisons.
        let context: [String: String]?
        let errorDescription: String?
    }

    private(set) var entries: [Entry] = []

    private static func stringify(_ context: [String: Any]?) -> [String: String]? {
        guard let context, !context.isEmpty else { return nil }
        return Dictionary(uniqueKeysWithValues: context.map { ($0.key, String(describing: $0.value)) })
    }

    func info(_ message: String, category: VTLogCategory, context: [String: Any]?) {
        entries.append(
            Entry(level: .info, message: message, category: category, context: Self.stringify(context), errorDescription: nil)
        )
    }

    func warn(_ message: String, category: VTLogCategory, context: [String: Any]?) {
        entries.append(
            Entry(level: .warn, message: message, category: category, context: Self.stringify(context), errorDescription: nil)
        )
    }

    func error(_ message: String, error: Error?, category: VTLogCategory, context: [String: Any]?) {
        entries.append(
            Entry(
                level: .error,
                message: message,
                category: category,
                context: Self.stringify(context),
                errorDescription: error.map { String(describing: $0) }
            )
        )
    }
}
