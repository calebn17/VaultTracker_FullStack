//
//  Account.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import Foundation
import SwiftData

/// Enum defining the different types of financial accounts a user can track.
enum AccountType: String, Codable, CaseIterable, Hashable {
    case bank = "Bank Account"
    case brokerage = "Brokerage"
    case cryptoExchange = "Crypto Exchange"
    case physicalWallet = "Physical Wallet"
    case cryptoWallet = "Crypto Wallet"
    case realEstate = "Real Estate"
    case other = "Other"
}

@Model
final class Account: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var name: String
    var accountType: AccountType
    var creationDate: Date
    
    init(id: UUID = UUID(), name: String, accountType: AccountType, creationDate: Date = Date()) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.creationDate = creationDate
    }
}
