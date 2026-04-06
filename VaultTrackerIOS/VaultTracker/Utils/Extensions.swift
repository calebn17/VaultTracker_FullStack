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
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        switch sanitized.count {
        case 3:
            red = Double((value >> 8) & 0xF) * 17 / 255
            green = Double((value >> 4) & 0xF) * 17 / 255
            blue = Double(value & 0xF) * 17 / 255
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            self = .clear
            return
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
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
