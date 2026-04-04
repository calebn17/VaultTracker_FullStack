//
//  VTLogCrashlyticsSupportTests.swift
//  VaultTrackerTests
//
//  Crashlytics SDK is only invoked from VTLogLive in non-DEBUG builds; these tests lock down the
//  payload shape (fixed-slot custom keys + NSError) that Phase 3 records as non-fatal events.

import Foundation
import Testing
@testable import VaultTracker

struct VTLogCrashlyticsSupportTests {

    private func keyValueMap(_ pairs: [(key: String, value: String)]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value) })
    }

    // MARK: - sanitizedKeySegment

    @Test func sanitizedKeySegment_replacesUnsafeCharactersWithUnderscores() {
        #expect(VTLogCrashlyticsSupport.sanitizedKeySegment("endpoint/path") == "endpoint_path")
    }

    @Test func sanitizedKeySegment_truncatesTo32Characters() {
        let long = String(repeating: "a", count: 40)
        #expect(VTLogCrashlyticsSupport.sanitizedKeySegment(long).count == 32)
    }

    // MARK: - crashlyticsCustomKeyValues (fixed vt_ctx_0… slots)

    @Test func crashlyticsCustomKeyValues_includesCategoryAndLevel() {
        let pairs = VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .api, isWarning: true, context: nil)
        let m = keyValueMap(pairs)
        #expect(m["vt_category"] == "api")
        #expect(m["vt_level"] == "warn")
        #expect(pairs.count == 2 + VTLogCrashlyticsSupport.crashlyticsContextSlotCount)
    }

    @Test func crashlyticsCustomKeyValues_errorLevel() {
        let m = keyValueMap(VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .auth, isWarning: false, context: nil))
        #expect(m["vt_level"] == "error")
    }

    @Test func crashlyticsCustomKeyValues_nilOrEmptyContext_clearsAllSlots() {
        for ctx: [String: Any]? in [nil, [:]] {
            let m = keyValueMap(VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .ui, isWarning: true, context: ctx))
            for i in 0..<VTLogCrashlyticsSupport.crashlyticsContextSlotCount {
                #expect(m["vt_ctx_\(i)"] == "")
            }
        }
    }

    @Test func crashlyticsCustomKeyValues_endpointPath_fullSlot0KeyAndValue() {
        let m = keyValueMap(
            VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .api, isWarning: false, context: ["endpoint/path": "x"])
        )
        #expect(m["vt_ctx_0"] == "endpoint_path=x")
        for i in 1..<VTLogCrashlyticsSupport.crashlyticsContextSlotCount {
            #expect(m["vt_ctx_\(i)"] == "")
        }
    }

    @Test func crashlyticsCustomKeyValues_sanitizedKeySegmentInSlotPayload() {
        let m = keyValueMap(
            VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .api, isWarning: true, context: ["a!b@c": 1])
        )
        #expect(m["vt_ctx_0"] == "a_b_c=1")
    }

    @Test func crashlyticsCustomKeyValues_orderingZAndA_exactSlotKeysAndValues() {
        let m = keyValueMap(
            VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .ui, isWarning: true, context: ["z": 1, "a": 2])
        )
        #expect(m["vt_ctx_0"] == "a=2")
        #expect(m["vt_ctx_1"] == "z=1")
        for i in 2..<VTLogCrashlyticsSupport.crashlyticsContextSlotCount {
            #expect(m["vt_ctx_\(i)"] == "")
        }
    }

    @Test func crashlyticsCustomKeyValues_twelveKeys_fillsFirstEightLexicographicSlotsRestEmpty() {
        var ctx: [String: Any] = [:]
        for i in 0..<12 {
            ctx["k\(i)"] = i
        }
        let m = keyValueMap(VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .api, isWarning: false, context: ctx))
        #expect(m["vt_ctx_0"] == "k0=0")
        #expect(m["vt_ctx_1"] == "k1=1")
        #expect(m["vt_ctx_2"] == "k10=10")
        #expect(m["vt_ctx_3"] == "k11=11")
        #expect(m["vt_ctx_4"] == "k2=2")
        #expect(m["vt_ctx_5"] == "k3=3")
        #expect(m["vt_ctx_6"] == "k4=4")
        #expect(m["vt_ctx_7"] == "k5=5")
    }

    @Test func crashlyticsCustomKeyValues_customSlotCount() {
        let pairs = VTLogCrashlyticsSupport.crashlyticsCustomKeyValues(category: .api, isWarning: true, context: ["a": 1], slotCount: 3)
        let m = keyValueMap(pairs)
        #expect(m["vt_ctx_0"] == "a=1")
        #expect(m["vt_ctx_1"] == "")
        #expect(m["vt_ctx_2"] == "")
        #expect(m["vt_ctx_3"] == nil)
    }

    // MARK: - recordableNSError

    @Test func recordableNSError_warnUsesCode0() {
        let err = VTLogCrashlyticsSupport.recordableNSError(message: "m", isWarning: true, underlying: nil)
        #expect(err.domain == VTLogCrashlyticsSupport.errorDomain)
        #expect(err.code == 0)
        #expect(err.localizedDescription == "m")
    }

    @Test func recordableNSError_errorUsesCode1() {
        let err = VTLogCrashlyticsSupport.recordableNSError(message: "m", isWarning: false, underlying: nil)
        #expect(err.code == 1)
    }

    @Test func recordableNSError_includesUnderlyingNSErrorWhenPresent() {
        let underlying = NSError(domain: "u", code: 42)
        let err = VTLogCrashlyticsSupport.recordableNSError(message: "wrapped", isWarning: false, underlying: underlying)
        let wrapped = err.userInfo[NSUnderlyingErrorKey] as? NSError
        #expect(wrapped?.domain == "u")
        #expect(wrapped?.code == 42)
    }

    @Test func recordableNSError_includesUnderlyingSwiftError_bridgedToNSError() {
        let urlError = URLError(.notConnectedToInternet)
        let err = VTLogCrashlyticsSupport.recordableNSError(message: "net", isWarning: false, underlying: urlError)
        let wrapped = err.userInfo[NSUnderlyingErrorKey] as? NSError
        #expect(wrapped != nil)
        #expect(wrapped?.domain == NSURLErrorDomain)
        #expect(wrapped?.code == URLError.Code.notConnectedToInternet.rawValue)
    }
}
