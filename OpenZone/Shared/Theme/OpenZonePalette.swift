import SwiftUI

/// OpenZone design system palette — cool paper base, blue galaxy accent, graphite controls.
/// Follows VISUAL_DESIGN_GUIDANCE.md for the "technical observatory" aesthetic.
public struct OpenZonePalette: Sendable {
    public let isDark: Bool

    // MARK: - Surfaces

    /// Main app background — cool off-white / deep blue-black
    public let surfaceBase: Color
    /// Paper-like sections — slightly tinted base
    public let surfacePaper: Color
    /// Raised panels, grouped content
    public let surfaceRaised: Color
    /// Secondary fills, quiet containers
    public let surfaceSubtle: Color
    /// Very light accent wash for selected fields
    public let surfaceGalaxyTint: Color

    // MARK: - Text

    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color

    // MARK: - Lines

    public let lineSoft: Color
    public let lineStrong: Color

    // MARK: - Accent (blue galaxy)

    /// Active state, progress, current step, command hint
    public let accentPrimary: Color
    /// Pressed accent, strong selection
    public let accentDeep: Color
    /// Accent background, quiet highlight
    public let accentSoft: Color

    // MARK: - Controls

    /// Primary CTA fill (graphite/near-black)
    public let controlStrong: Color
    /// Text on strong controls
    public let controlStrongText: Color

    // MARK: - Status

    public let success: Color
    public let warning: Color
    public let danger: Color

    /// Resolve palette for the given color scheme.
    public static func resolve(_ scheme: ColorScheme) -> OpenZonePalette {
        if scheme == .dark {
            return OpenZonePalette(
                isDark: true,
                surfaceBase: Color(hex: "090D18"),
                surfacePaper: Color(hex: "0D1424"),
                surfaceRaised: Color(hex: "111827"),
                surfaceSubtle: Color(hex: "162033"),
                surfaceGalaxyTint: Color(hex: "172B57"),
                textPrimary: Color(hex: "F4F7FB"),
                textSecondary: Color(hex: "AAB5C6"),
                textTertiary: Color(hex: "7E8AA0"),
                lineSoft: Color(hex: "2B364A"),
                lineStrong: Color(hex: "3F4E68"),
                accentPrimary: Color(hex: "6FA0FF"),
                accentDeep: Color(hex: "9DBDFF"),
                accentSoft: Color(hex: "172B57"),
                controlStrong: Color(hex: "F4F7FB"),
                controlStrongText: Color(hex: "111318"),
                success: Color(hex: "63E6BE"),
                warning: Color(hex: "FFD166"),
                danger: Color(hex: "FF8A8A")
            )
        }

        return OpenZonePalette(
            isDark: false,
            surfaceBase: Color(hex: "F7F9FD"),
            surfacePaper: Color(hex: "F2F6FC"),
            surfaceRaised: Color(hex: "FFFFFF"),
            surfaceSubtle: Color(hex: "EAF0FA"),
            surfaceGalaxyTint: Color(hex: "DDE8FF"),
            textPrimary: Color(hex: "111318"),
            textSecondary: Color(hex: "687180"),
            textTertiary: Color(hex: "9BA6B6"),
            lineSoft: Color(hex: "D9E1EE"),
            lineStrong: Color(hex: "B8C4D6"),
            accentPrimary: Color(hex: "2F6BFF"),
            accentDeep: Color(hex: "1239A6"),
            accentSoft: Color(hex: "DDE8FF"),
            controlStrong: Color(hex: "111318"),
            controlStrongText: Color(hex: "FFFFFF"),
            success: Color(hex: "087F5B"),
            warning: Color(hex: "9A6700"),
            danger: Color(hex: "C92A2A")
        )
    }
}
