//
//  AssetModel.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/27/25.
//

import Foundation

import SwiftData

public enum AssetCategory: String, Codable, CaseIterable {
    case crypto = "Crypto"
    case stocks = "Stocks/ETFs"
    case realEstate = "Real Estate"
    case cash = "Cash"
    case retirement = "Retirement"
}

@MainActor @Model
final class Asset: Sendable {
    var id: UUID
    var name: String
    var category: AssetCategory
    var symbol: String                // For priced assets like crypto & stocks
    var quantity: Double
    var price: Double
    var currentValue: Double
    var notes: String?
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: AssetCategory,
        symbol: String,
        quantity: Double,
        purchasePrice: Double,
        currentValue: Double,
        notes: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.symbol = symbol
        self.quantity = quantity
        self.price = purchasePrice
        self.currentValue = currentValue
        self.notes = notes
        self.lastUpdated = lastUpdated
    }
}
