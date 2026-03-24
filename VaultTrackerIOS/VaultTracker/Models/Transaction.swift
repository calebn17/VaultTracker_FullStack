//
//  Transaction.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import Foundation

/// The type of transaction.
enum TransactionType: String, Codable, Hashable, CaseIterable {
    case buy = "Buy"
    case sell = "Sell"
}

struct Transaction: Sendable, Identifiable {
    var id: UUID

    // Transaction Details
    var transactionType: TransactionType
    var quantity: Double
    var pricePerUnit: Double
    var date: Date

    // Asset Details
    var name: String
    var symbol: String // Symbol for cash and real estate is the `name`
    var category: AssetCategory

    // Relationship
    var account: Account

    init(
        id: UUID = UUID(),
        transactionType: TransactionType,
        quantity: Double,
        pricePerUnit: Double,
        date: Date,
        name: String,
        symbol: String,
        category: AssetCategory,
        account: Account
    ) {
        self.id = id
        self.transactionType = transactionType
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.date = date
        self.name = name
        self.symbol = symbol
        self.category = category
        self.account = account
    }
}
