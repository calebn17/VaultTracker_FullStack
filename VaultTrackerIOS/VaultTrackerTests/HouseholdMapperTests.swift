//
//  HouseholdMapperTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

@Suite("HouseholdMapper", .serialized)
struct HouseholdMapperTests {

    @Test func mapsHouseholdResponseToDomain() throws {
        let json = """
        {"id":"hh-1","createdAt":"2020-01-01T00:00:00Z","members":[{"userId":"u1","email":"a@b.com"}]}
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let api = try dec.decode(APIHouseholdResponse.self, from: json)
        let h = HouseholdMapper.toDomain(api)
        #expect(h.id == "hh-1")
        #expect(h.members.count == 1)
        #expect(h.members[0].userId == "u1")
        #expect(h.members[0].email == "a@b.com")
    }
}
