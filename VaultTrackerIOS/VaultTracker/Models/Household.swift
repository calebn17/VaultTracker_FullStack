//
//  Household.swift
//  VaultTracker
//
//  Domain types for multi-account (household) features.
//

import Foundation

struct Household: Equatable {
    let id: String
    let members: [HouseholdMember]
    let createdAt: Date
}

struct HouseholdMember: Equatable {
    let userId: String
    let email: String?
}

struct HouseholdInviteCode: Equatable {
    let code: String
    let expiresAt: Date
}
