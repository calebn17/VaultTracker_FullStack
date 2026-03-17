
//
//  NetWorthSnapshot.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import Foundation

struct NetWorthSnapshot: Sendable {
    var date: Date
    var value: Double

    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
