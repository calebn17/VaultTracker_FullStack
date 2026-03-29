//
//  VTComponents.swift
//  VaultTracker
//

import SwiftUI

struct VTPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(VTColors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [VTColors.primary, VTColors.primaryDim],
                            startPoint: UnitPoint(x: 0, y: 0),
                            endPoint: UnitPoint(x: 1, y: 1)
                        )
                    )
            }
            .opacity(buttonOpacity(isPressed: configuration.isPressed))
    }

    private func buttonOpacity(isPressed: Bool) -> Double {
        let base = isEnabled ? 1.0 : 0.4
        return base * (isPressed ? 0.85 : 1)
    }
}

enum VTSurfaceLevel {
    case low
    case standard
    case high
}

struct SurfaceCardModifier: ViewModifier {
    let level: VTSurfaceLevel

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backgroundColor: Color {
        switch level {
        case .low: return VTColors.surfaceLow
        case .standard: return VTColors.surface
        case .high: return VTColors.surfaceHigh
        }
    }
}

extension View {
    func vtSurfaceCard(_ level: VTSurfaceLevel = .standard) -> some View {
        modifier(SurfaceCardModifier(level: level))
    }
}

struct FilterChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VTFonts.caption.weight(.medium))
            .foregroundStyle(isSelected ? VTColors.background : VTColors.textSubdued)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? VTColors.primary : VTColors.surface)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct VTSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(VTColors.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(VTColors.surfaceHigh)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
