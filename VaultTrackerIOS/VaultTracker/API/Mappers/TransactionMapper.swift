//
//  TransactionMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

// Maps `APIEnrichedTransactionResponse` (nested asset + account) to domain `Transaction`.

import Foundation

enum TransactionMapper {

    /// Map an enriched API row (nested asset + account) to a domain `Transaction`.
    @MainActor
    static func toDomain(_ response: APIEnrichedTransactionResponse) -> Transaction {
        Transaction(
            id: UUID(uuidString: response.id) ?? UUID(),
            transactionType: mapTransactionType(response.transactionType),
            quantity: response.quantity,
            pricePerUnit: response.pricePerUnit,
            date: response.date,
            name: response.asset.name,
            symbol: response.asset.symbol ?? response.asset.name,
            category: AssetMapper.mapCategory(response.asset.category),
            account: AccountMapper.toDomain(response.account)
        )
    }

    @MainActor
    static func toDomain(_ responses: [APIEnrichedTransactionResponse]) -> [Transaction] {
        responses.map { toDomain($0) }
    }

    // MARK: - Private

    private static func mapTransactionType(_ raw: String) -> TransactionType {
        switch raw {
        case "buy":  return .buy
        case "sell": return .sell
        default:     return .buy
        }
    }
}
