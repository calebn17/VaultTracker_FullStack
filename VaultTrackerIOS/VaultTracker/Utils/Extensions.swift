//
//  Extensions.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import Foundation
import SwiftUI

extension Color {
    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (hex digits only after `#`).
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value) else {
            self = .clear
            return
        }
        let r, g, b, a: Double
        switch sanitized.count {
        case 3:
            r = Double((value >> 8) & 0xF) * 17 / 255
            g = Double((value >> 4) & 0xF) * 17 / 255
            b = Double(value & 0xF) * 17 / 255
            a = 1
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            self = .clear
            return
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

extension Double {
    var twoDecimalString: String {
            return String(format: "%.2f", self)
        }
    
    func currencyFormat() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? ""
    }
}
