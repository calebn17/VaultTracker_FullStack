//
//  APIFIREModels.swift
//  VaultTracker
//
//  Personal and household FIRE profiles share these shapes (camelCase JSON).
//

import Foundation

// MARK: - Profile (GET/PUT)

/// Request body for PUT /api/v1/fire/profile and PUT /api/v1/households/me/fire-profile
struct APIFIREProfileInput: Codable {
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let targetRetirementAge: Int?
}

/// Response for GET /api/v1/fire/profile and GET /api/v1/households/me/fire-profile
struct APIFIREProfileResponse: Codable {
    let id: String
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let targetRetirementAge: Int?
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Projection (GET /api/v1/fire/projection)

/// Response for GET /api/v1/fire/projection
struct APIFIREProjectionResponse: Codable {
    let status: String
    let unreachableReason: String?
    let inputs: APIFIREProjectionInputs
    let allocation: APIFIREAllocation?
    let blendedReturn: Double?
    let realBlendedReturn: Double?
    let inflationRate: Double?
    let annualSavings: Double?
    let savingsRate: Double?
    let fireTargets: APIFIRETargets
    let projectionCurve: [APIFIREProjectionPoint]
    let monthlyBreakdown: APIFIREMonthlyBreakdown
    let goalAssessment: APIFIREGoalAssessment?
}

struct APIFIREProjectionInputs: Codable {
    let currentAge: Int
    let annualIncome: Double
    let annualExpenses: Double
    let currentNetWorth: Double
    let targetRetirementAge: Int?
}

struct APIFIREAllocationSlice: Codable {
    let value: Double
    let percentage: Double
    let expectedReturn: Double
}

struct APIFIREAllocation: Codable {
    let crypto: APIFIREAllocationSlice
    let stocks: APIFIREAllocationSlice
    let cash: APIFIREAllocationSlice
    let realEstate: APIFIREAllocationSlice
    let retirement: APIFIREAllocationSlice
}

struct APIFIRETargetTier: Codable {
    let targetAmount: Double
    let yearsToTarget: Int?
    let targetAge: Int?
}

struct APIFIRETargets: Codable {
    let leanFire: APIFIRETargetTier
    let fire: APIFIRETargetTier
    let fatFire: APIFIRETargetTier
}

struct APIFIREProjectionPoint: Codable {
    let age: Int
    let year: Int
    let projectedValue: Double
}

struct APIFIREMonthlyBreakdown: Codable {
    let monthlySurplus: Double
    let monthsToFire: Int?
}

struct APIFIREGoalAssessment: Codable {
    let targetAge: Int
    let requiredSavingsRate: Double
    let currentSavingsRate: Double
    let status: String
    let gapAmount: Double
    let computedBeyondProjectionHorizon: Bool
}
