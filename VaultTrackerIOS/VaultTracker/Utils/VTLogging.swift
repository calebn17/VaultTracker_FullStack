//
//  VTLogging.swift
//  VaultTracker
//
//  Abstraction for structured logs (OSLog + Crashlytics in RELEASE). Inject `VTLoggingSpy` in tests.

import Foundation
import os

/// Subsystem categories for filtering in Console.app and Xcode.
enum VTLogCategory: String {
    case api
    case auth
    case ui
}

/// Production logging surface. Default implementation: ``VTLogLive``.
protocol VTLogging {
    func info(_ message: String, category: VTLogCategory, context: [String: Any]?)
    func warn(_ message: String, category: VTLogCategory, context: [String: Any]?)
    func error(_ message: String, error: Error?, category: VTLogCategory, context: [String: Any]?)
}

/// OSLog-backed logger; Crashlytics hooks in RELEASE (Phase 3).
struct VTLogLive: VTLogging {

    private static let subsystem = "com.vaulttracker"

    private func osLogger(for category: VTLogCategory) -> Logger {
        Logger(subsystem: Self.subsystem, category: category.rawValue)
    }

    private func contextSuffix(_ context: [String: Any]?) -> String {
        guard let context, !context.isEmpty else { return "" }
        let pairs = context
            .map { "\($0.key)=\(String(describing: $0.value))" }
            .sorted()
        return " " + pairs.joined(separator: " ")
    }

    func info(_ message: String, category: VTLogCategory, context: [String: Any]?) {
        let log = osLogger(for: category)
        let suffix = contextSuffix(context)
        log.info("\(message, privacy: .public)\(suffix, privacy: .public)")
    }

    func warn(_ message: String, category: VTLogCategory, context: [String: Any]?) {
        let log = osLogger(for: category)
        let suffix = contextSuffix(context)
        log.warning("\(message, privacy: .public)\(suffix, privacy: .public)")
#if !DEBUG
        recordNonFatalStub(message: message, error: nil, context: context)
#endif
    }

    func error(_ message: String, error: Error?, category: VTLogCategory, context: [String: Any]?) {
        let log = osLogger(for: category)
        let errPart = error.map { " underlying=\(String(describing: $0))" } ?? ""
        let suffix = contextSuffix(context) + errPart
        log.error("\(message, privacy: .public)\(suffix, privacy: .public)")
#if !DEBUG
        recordNonFatalStub(message: message, error: error, context: context)
#endif
    }

#if !DEBUG
    private func recordNonFatalStub(message: String, error: Error?, context: [String: Any]?) {
        // TODO Phase 3: wire Crashlytics here
        _ = (message, error, context)
    }
#endif
}

// MARK: - Context shorthands

extension VTLogging {
    func info(_ message: String, category: VTLogCategory) {
        info(message, category: category, context: nil)
    }

    func warn(_ message: String, category: VTLogCategory) {
        warn(message, category: category, context: nil)
    }

    /// Same as ``error(_:error:category:context:)`` with no structured context.
    func error(_ message: String, error err: Error?, category: VTLogCategory) {
        self.error(message, error: err, category: category, context: nil)
    }
}
