//
//  VTLogging.swift
//  VaultTracker
//
//  Abstraction for structured logs (OSLog + Crashlytics in RELEASE). Inject `VTLoggingSpy` in tests.

import Foundation
import os
#if !DEBUG
import FirebaseCrashlytics
#endif

/// Subsystem categories for filtering in Console.app and Xcode.
enum VTLogCategory: String {
    case api
    case auth
    case ui
}

/// Pure helpers for Crashlytics custom keys and recorded `NSError`s (unit-tested; used from ``VTLogLive`` in non-DEBUG).
enum VTLogCrashlyticsSupport {
    static let errorDomain = "com.vaulttracker"

    /// Fixed number of `vt_ctx_*` slots sent on every non-fatal so prior events do not leave stale keys in Crashlytics.
    static let crashlyticsContextSlotCount = 8

    /// Sanitize the original context key for the `sanitizedKey=value` slot payload (alphanumeric + underscore, max 32 chars).
    static func sanitizedKeySegment(_ key: String) -> String {
        let cleaned = key.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
        return String(cleaned.prefix(32))
    }

    /// All `setCustomValue` pairs for one non-fatal: `vt_category`, `vt_level`, then
    /// `vt_ctx_0`…`vt_ctx_{N-1}`. Slot `index` is
    /// `"\(sanitizedKeySegment(originalKey))=\(String(describing: value))"` for the
    /// *index*-th context entry in ascending key order, or `""` if unused (clears a
    /// previous upload for that slot).
    static func crashlyticsCustomKeyValues(
        category: VTLogCategory,
        isWarning: Bool,
        context: [String: Any]?,
        slotCount: Int = crashlyticsContextSlotCount
    ) -> [(key: String, value: String)] {
        var result: [(String, String)] = [
            ("vt_category", category.rawValue),
            ("vt_level", isWarning ? "warn" : "error")
        ]
        let sorted = (context ?? [:]).sorted { $0.key < $1.key }
        for index in 0..<slotCount {
            if index < sorted.count {
                let (key, value) = sorted[index]
                let segment = sanitizedKeySegment(key)
                result.append(("vt_ctx_\(index)", "\(segment)=\(String(describing: value))"))
            } else {
                result.append(("vt_ctx_\(index)", ""))
            }
        }
        return result
    }

    /// `NSError` passed to `Crashlytics.record(error:)` for non-fatal log lines.
    static func recordableNSError(message: String, isWarning: Bool, underlying: Error?) -> NSError {
        let code = isWarning ? 0 : 1
        if let underlying {
            return NSError(
                domain: errorDomain,
                code: code,
                userInfo: [NSLocalizedDescriptionKey: message, NSUnderlyingErrorKey: underlying]
            )
        }
        return NSError(domain: errorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

/// Production logging surface. Default implementation: ``VTLogLive``.
protocol VTLogging {
    func info(_ message: String, category: VTLogCategory, context: [String: Any]?)
    func warn(_ message: String, category: VTLogCategory, context: [String: Any]?)
    func error(_ message: String, error: Error?, category: VTLogCategory, context: [String: Any]?)
}

/// OSLog-backed logger; non-fatal `warn` / `error` also go to Crashlytics in non-DEBUG builds.
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
        recordNonFatalToCrashlytics(message: message, category: category, isWarning: true, underlying: nil, context: context)
#endif
    }

    func error(_ message: String, error: Error?, category: VTLogCategory, context: [String: Any]?) {
        let log = osLogger(for: category)
        let errPart = error.map { " underlying=\(String(describing: $0))" } ?? ""
        let suffix = contextSuffix(context) + errPart
        log.error("\(message, privacy: .public)\(suffix, privacy: .public)")
#if !DEBUG
        recordNonFatalToCrashlytics(message: message, category: category, isWarning: false, underlying: error, context: context)
#endif
    }

#if !DEBUG
    /// Crashlytics custom keys must be plist-safe; stringify everything and cap count.
    private func recordNonFatalToCrashlytics(
        message: String,
        category: VTLogCategory,
        isWarning: Bool,
        underlying: Error?,
        context: [String: Any]?
    ) {
        let crashlytics = Crashlytics.crashlytics()
        for pair in VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: category, isWarning: isWarning, context: context) {
            crashlytics.setCustomValue(pair.value, forKey: pair.key)
        }
        let nsError = VTLogCrashlyticsSupport.recordableNSError(message: message, isWarning: isWarning, underlying: underlying)
        crashlytics.record(error: nsError)
    }
#endif
}

/// Default app logger for call sites that do not use dependency injection (views, `AuthTokenProvider`, etc.).
enum VTLog {
    static let shared: any VTLogging = VTLogLive()
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
