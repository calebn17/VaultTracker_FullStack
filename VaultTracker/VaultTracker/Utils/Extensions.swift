//
//  Extensions.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import Foundation

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
