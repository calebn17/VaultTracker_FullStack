//
//  APIModelsCodableTests.swift
//  VaultTrackerTests
//
//  These exercises encode/decode our Codable API models against hand-written JSON.
//  When the corresponding VaultTrackerAPI routes or Pydantic schemas change, update
//  the fixtures and expectations here so the suite stays aligned with the wire format.
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("API models Codable", .serialized)
struct APIModelsCodableTests {

    @Test func smartTransactionRequestEncodesSnakeCaseKeys() throws {
        let req = APISmartTransactionCreateRequest(
            transactionType: "buy",
            category: "stocks",
            assetName: "Acme",
            symbol: "ACM",
            quantity: 3,
            pricePerUnit: 12.5,
            accountName: "My Bank",
            accountType: "brokerage",
            date: nil
        )
        let data = try JSONEncoder().encode(req)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(obj["transaction_type"] as? String == "buy")
        #expect(obj["asset_name"] as? String == "Acme")
        #expect(obj["price_per_unit"] as? Double == 12.5)
        #expect(obj["account_name"] as? String == "My Bank")
        #expect(obj["account_type"] as? String == "brokerage")
        #expect(obj["symbol"] as? String == "ACM")
    }

    @Test func analyticsResponseDecodesFromJSON() throws {
        let json = """
        {
          "allocation": {
            "crypto": { "value": 1000.0, "percentage": 40.0 },
            "stocks": { "value": 1500.0, "percentage": 60.0 }
          },
          "performance": {
            "totalGainLoss": 100.0,
            "totalGainLossPercent": 5.5,
            "costBasis": 2000.0,
            "currentValue": 2100.0
          }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(APIAnalyticsResponse.self, from: json)
        #expect(decoded.allocation["crypto"]?.value == 1000)
        #expect(decoded.allocation["crypto"]?.percentage == 40)
        #expect(decoded.performance.costBasis == 2000)
        #expect(decoded.performance.currentValue == 2100)
    }

    @Test func priceRefreshResultDecodesFromJSON() throws {
        let json = """
        {
          "updated": [
            {
              "asset_id": "a1",
              "symbol": "BTC",
              "old_value": 100.0,
              "new_value": 200.0,
              "price": 50000.0
            }
          ],
          "skipped": ["Cash"],
          "errors": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(APIPriceRefreshResult.self, from: json)
        #expect(decoded.updated.count == 1)
        #expect(decoded.updated[0].assetId == "a1")
        #expect(decoded.updated[0].price == 50_000)
        #expect(decoded.skipped == ["Cash"])
        #expect(decoded.errors.isEmpty)
    }

    @Test func accountResponseDecodesSnakeCaseKeys() throws {
        let json = """
        {
          "id": "acct-1",
          "user_id": "user-1",
          "name": "Chase Checking",
          "account_type": "bank",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let account = try decoder.decode(APIAccountResponse.self, from: json)

        #expect(account.name == "Chase Checking")
        #expect(account.accountType == "bank")
        #expect(account.id == "acct-1")
    }

    @Test func assetResponseDecodesSnakeCaseKeys() throws {
        let json = """
        {
          "id": "asset-1",
          "user_id": "user-1",
          "name": "Bitcoin",
          "symbol": "BTC",
          "category": "crypto",
          "quantity": 0.5,
          "current_value": 30000.0,
          "last_updated": "2026-03-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let asset = try decoder.decode(APIAssetResponse.self, from: json)

        #expect(asset.name == "Bitcoin")
        #expect(asset.symbol == "BTC")
        #expect(asset.category == "crypto")
        #expect(asset.quantity == 0.5)
        #expect(asset.currentValue == 30_000)
    }

    @Test func netWorthHistoryResponseDecodesFromJSON() throws {
        let json = """
        {
          "snapshots": [
            { "date": "2026-01-15T00:00:00Z", "value": 50000.0 },
            { "date": "2026-02-15T00:00:00Z", "value": 75000.0 }
          ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let history = try decoder.decode(APINetWorthHistoryResponse.self, from: json)

        #expect(history.snapshots.count == 2)
        #expect(history.snapshots[0].value == 50_000)
        #expect(history.snapshots[1].value == 75_000)
    }

    @Test func enrichedTransactionDecodesNestedAssetAndAccount() throws {
        let json = """
        {
          "id": "t1",
          "user_id": "u1",
          "asset_id": "as1",
          "account_id": "ac1",
          "transaction_type": "buy",
          "quantity": 1.0,
          "price_per_unit": 10.0,
          "total_value": 10.0,
          "date": "2026-01-15T12:00:00Z",
          "asset": {
            "id": "as1",
            "name": "Thing",
            "symbol": "THG",
            "category": "stocks"
          },
          "account": {
            "id": "ac1",
            "name": "Broker",
            "account_type": "brokerage"
          }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(APIEnrichedTransactionResponse.self, from: json)
        #expect(row.asset.name == "Thing")
        #expect(row.account.accountType == "brokerage")
        #expect(row.totalValue == 10)
    }

    @Test func householdResponseDecodesFromJSON() throws {
        let json = """
        {
          "id": "hh-1",
          "createdAt": "2026-04-20T12:00:00Z",
          "members": [
            { "userId": "u1", "email": "a@example.com" },
            { "userId": "u2", "email": null }
          ]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let h = try decoder.decode(APIHouseholdResponse.self, from: json)
        #expect(h.id == "hh-1")
        #expect(h.members.count == 2)
        #expect(h.members[0].userId == "u1")
        #expect(h.members[0].email == "a@example.com")
        #expect(h.members[1].email == nil)
    }

    @Test func householdJoinRequestEncodesCodeKey() throws {
        let req = APIHouseholdJoinRequest(code: "ABCD1234")
        let data = try JSONEncoder().encode(req)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["code"] as? String == "ABCD1234")
    }

    @Test func householdDashboardDecodesNestedGroupedHoldings() throws {
        let json = """
        {
          "householdId": "hh-1",
          "totalNetWorth": 100000.0,
          "categoryTotals": {
            "crypto": 0.0,
            "stocks": 100000.0,
            "cash": 0.0,
            "realEstate": 0.0,
            "retirement": 0.0
          },
          "members": [
            {
              "userId": "u1",
              "email": "a@example.com",
              "totalNetWorth": 50000.0,
              "categoryTotals": {
                "crypto": 0.0,
                "stocks": 50000.0,
                "cash": 0.0,
                "realEstate": 0.0,
                "retirement": 0.0
              },
              "groupedHoldings": {
                "stocks": [
                  {
                    "id": "as1",
                    "name": "Acme",
                    "symbol": "ACM",
                    "quantity": 1.0,
                    "current_value": 50000.0
                  }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(APIHouseholdDashboardResponse.self, from: json)
        #expect(d.householdId == "hh-1")
        #expect(d.totalNetWorth == 100_000)
        #expect(d.members[0].groupedHoldings["stocks"]?.first?.currentValue == 50_000)
    }

    @Test func fireProfileInputEncodesCamelCaseKeys() throws {
        let input = APIFIREProfileInput(
            currentAge: 35,
            annualIncome: 120_000,
            annualExpenses: 60_000,
            targetRetirementAge: 55
        )
        let data = try JSONEncoder().encode(input)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["currentAge"] as? Int == 35)
        #expect(obj["annualIncome"] as? Double == 120_000)
        #expect(obj["annualExpenses"] as? Double == 60_000)
        #expect(obj["targetRetirementAge"] as? Int == 55)
    }

    @Test func fireProfileResponseDecodesFromJSON() throws {
        let json = """
        {
          "id": "fp-1",
          "currentAge": 40,
          "annualIncome": 100000.0,
          "annualExpenses": 50000.0,
          "targetRetirementAge": 60,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(APIFIREProfileResponse.self, from: json)
        #expect(p.id == "fp-1")
        #expect(p.currentAge == 40)
        #expect(p.targetRetirementAge == 60)
    }

    @Test func fireProjectionResponseDecodesMinimalPayload() throws {
        let json = """
        {
          "status": "reachable",
          "unreachableReason": null,
          "inputs": {
            "currentAge": 30,
            "annualIncome": 100000.0,
            "annualExpenses": 50000.0,
            "currentNetWorth": 200000.0,
            "targetRetirementAge": 60
          },
          "allocation": null,
          "blendedReturn": 0.07,
          "realBlendedReturn": 0.04,
          "inflationRate": 0.03,
          "annualSavings": 20000.0,
          "savingsRate": 0.2,
          "fireTargets": {
            "leanFire": { "targetAmount": 1.0, "yearsToTarget": 20, "targetAge": 50 },
            "fire": { "targetAmount": 2.0, "yearsToTarget": 25, "targetAge": 55 },
            "fatFire": { "targetAmount": 5.0, "yearsToTarget": null, "targetAge": 60 }
          },
          "projectionCurve": [
            { "age": 30, "year": 2026, "projectedValue": 200000.0 }
          ],
          "monthlyBreakdown": { "monthlySurplus": 2000.0, "monthsToFire": 120 },
          "goalAssessment": null
        }
        """.data(using: .utf8)!
        let p = try JSONDecoder().decode(APIFIREProjectionResponse.self, from: json)
        #expect(p.status == "reachable")
        #expect(p.unreachableReason == nil)
        #expect(p.inputs.currentNetWorth == 200_000)
        #expect(p.fireTargets.fire.targetAmount == 2.0)
        #expect(p.projectionCurve.count == 1)
        #expect(p.monthlyBreakdown.monthsToFire == 120)
    }
}
