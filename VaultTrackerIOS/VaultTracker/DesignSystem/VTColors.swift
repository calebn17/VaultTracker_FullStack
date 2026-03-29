//
//  VTColors.swift
//  VaultTracker
//

import SwiftUI

enum VTColors {
    static let background = Color(hex: "#111317")
    static let surfaceLow = Color(hex: "#1A1D23")
    static let surface = Color(hex: "#22252B")
    static let surfaceHigh = Color(hex: "#2A2D33")
    static let primary = Color(hex: "#C5F261")
    static let primaryDim = Color(hex: "#AAD548")
    static let secondary = Color(hex: "#70D2FF")
    static let tertiary = Color(hex: "#FFB77A")
    static let error = Color(hex: "#FFB4AB")
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSubdued = Color.white.opacity(0.6)
    static let ghostBorder = Color.white.opacity(0.15)

    private static let realEstateAccent = Color(hex: "#E879F9")
    private static let retirementAccent = Color(hex: "#A78BFA")

    static func categoryAccent(_ category: AssetCategory) -> Color {
        switch category {
        case .stocks: return secondary
        case .crypto: return tertiary
        case .cash: return primary
        case .realEstate: return realEstateAccent
        case .retirement: return retirementAccent
        }
    }
}
