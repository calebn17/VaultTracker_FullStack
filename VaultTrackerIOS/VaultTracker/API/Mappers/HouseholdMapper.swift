//
//  HouseholdMapper.swift
//  VaultTracker
//

import Foundation

enum HouseholdMapper {

    static func toDomain(_ response: APIHouseholdResponse) -> Household {
        Household(
            id: response.id,
            members: response.members.map { HouseholdMember(userId: $0.userId, email: $0.email) },
            createdAt: response.createdAt
        )
    }

    static func inviteToDomain(_ response: APIHouseholdInviteCodeResponse) -> HouseholdInviteCode {
        HouseholdInviteCode(code: response.code, expiresAt: response.expiresAt)
    }
}
