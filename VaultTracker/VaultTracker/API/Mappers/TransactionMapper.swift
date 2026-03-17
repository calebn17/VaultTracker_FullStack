//
//  TransactionMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

// Converts APITransactionResponse values into domain Transaction models.
// Because the Transaction domain model embeds asset name/symbol/category and an
// Account reference inline, callers must supply pre-built lookup dictionaries
// keyed by server ID. Transactions whose asset or account ID cannot be resolved
// are silently dropped via compactMap, so the UI always shows a consistent set.

import Foundation

enum TransactionMapper {

    /// Convert an API transaction response to the app's domain Transaction model.
    ///
    /// **Context required:** The existing `Transaction` model embeds asset details
    /// (name, symbol, category) inline and holds a direct `Account` reference.
    /// The API response only carries `assetId` and `accountId` (foreign keys), so
    /// the caller must supply lookup dictionaries keyed by the server string ID.
    ///
    /// If either the asset or account cannot be found in the provided dictionaries,
    /// this method returns `nil` and the transaction is skipped.
    ///
    /// - Parameters:
    ///   - response: The raw API transaction response.
    ///   - assetsByID: Map of server asset ID → domain Asset, for name/symbol/category.
    ///   - accountsByID: Map of server account ID → domain Account, for the relationship.
    @MainActor
    static func toDomain(
        _ response: APITransactionResponse,
        assetsByID: [String: Asset],
        accountsByID: [String: Account]
    ) -> Transaction? {
        guard
            let asset = assetsByID[response.assetId],
            let account = accountsByID[response.accountId]
        else {
            return nil
        }

        return Transaction(
            id: UUID(uuidString: response.id) ?? UUID(),
            transactionType: mapTransactionType(response.transactionType),
            quantity: response.quantity,
            pricePerUnit: response.pricePerUnit,
            date: response.date,
            name: asset.name,
            symbol: asset.symbol,
            category: asset.category,
            account: account
        )
    }

    /// Convert an array of API transaction responses to domain models.
    /// Transactions whose asset or account cannot be resolved are dropped.
    @MainActor
    static func toDomain(
        _ responses: [APITransactionResponse],
        assetsByID: [String: Asset],
        accountsByID: [String: Account]
    ) -> [Transaction] {
        responses.compactMap {
            toDomain($0, assetsByID: assetsByID, accountsByID: accountsByID)
        }
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
