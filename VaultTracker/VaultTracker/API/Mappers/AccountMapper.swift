//
//  AccountMapper.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

// Converts APIAccountResponse values into domain Account models.
// Server UUIDs are parsed from strings and fall back to a new UUID on failure.
// API account type strings (e.g. "crypto_exchange") are mapped to the app's
// AccountType enum; types with no direct equivalent default to .other.

import Foundation

enum AccountMapper {

    /// Convert an API account response to the app's domain Account model.
    ///
    /// **ID handling:** The API returns String UUIDs. We parse them with
    /// `UUID(uuidString:)` and fall back to a new UUID if parsing fails
    /// (which should never happen with a well-behaved backend).
    ///
    /// **AccountType mapping:** The API subset (`cryptoExchange`, `brokerage`,
    /// `bank`, `retirement`, `other`) maps 1-to-1 with existing cases.
    /// The app has extra local-only types (`physicalWallet`, `cryptoWallet`,
    /// `realEstate`) that have no API equivalent and will not appear in
    /// server responses.
    @MainActor
    static func toDomain(_ response: APIAccountResponse) -> Account {
        Account(
            id: UUID(uuidString: response.id) ?? UUID(),
            name: response.name,
            accountType: mapAccountType(response.accountType),
            creationDate: response.createdAt
        )
    }

    /// Convert an array of API account responses to domain models.
    @MainActor
    static func toDomain(_ responses: [APIAccountResponse]) -> [Account] {
        responses.map { toDomain($0) }
    }

    // MARK: - Private

    private static func mapAccountType(_ raw: String) -> AccountType {
        switch raw {
        case "crypto_exchange", "cryptoExchange": return .cryptoExchange
        case "brokerage":                         return .brokerage
        case "bank":                              return .bank
        case "retirement":                        return .other // closest local equivalent
        default:                                  return .other
        }
    }
}
