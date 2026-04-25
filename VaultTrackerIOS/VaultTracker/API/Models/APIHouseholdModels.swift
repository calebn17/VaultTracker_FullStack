//
//  APIHouseholdModels.swift
//  VaultTracker
//

import Foundation

// MARK: - Household summary

/// Response for GET /api/v1/households/me and POST /api/v1/households
struct APIHouseholdResponse: Codable {
    let id: String
    let members: [APIHouseholdMember]
    let createdAt: Date
}

struct APIHouseholdMember: Codable {
    let userId: String
    let email: String?
}

// MARK: - Invite codes

/// Response for POST /api/v1/households/invite-codes
struct APIHouseholdInviteCodeResponse: Codable {
    let code: String
    let expiresAt: Date
}

// MARK: - Join

/// Body for POST /api/v1/households/join
struct APIHouseholdJoinRequest: Codable {
    let code: String
}

// MARK: - Household dashboard

/// Response for GET /api/v1/dashboard/household
struct APIHouseholdDashboardResponse: Codable {
    let householdId: String
    let totalNetWorth: Double
    let categoryTotals: APICategoryTotals
    let members: [APIHouseholdMemberDashboard]
}

struct APIHouseholdMemberDashboard: Codable {
    let userId: String
    let email: String?
    let totalNetWorth: Double
    let categoryTotals: APICategoryTotals
    let groupedHoldings: [String: [APIGroupedHolding]]
}
