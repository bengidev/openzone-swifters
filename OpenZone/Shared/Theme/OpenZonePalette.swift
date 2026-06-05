import SwiftUI

/// OpenZone design system palette — monochrome: neutral paper base, graphite accent, ink controls.
/// Fully grayscale (hue-less) ramp; hierarchy carried by lightness and contrast.
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
    /// Very light neutral wash for selected fields
    public let surfaceGalaxyTint: Color

    // MARK: - Text

    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color

    // MARK: - Lines

    public let lineSoft: Color
    public let lineStrong: Color

    // MARK: - Accent (graphite)

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
                surfaceBase: Color(hex: "0B0B0B"),
                surfacePaper: Color(hex: "121212"),
                surfaceRaised: Color(hex: "1A1A1A"),
                surfaceSubtle: Color(hex: "242424"),
                surfaceGalaxyTint: Color(hex: "2C2C2C"),
                textPrimary: Color(hex: "F5F5F5"),
                textSecondary: Color(hex: "B0B0B0"),
                textTertiary: Color(hex: "7E7E7E"),
                lineSoft: Color(hex: "2E2E2E"),
                lineStrong: Color(hex: "484848"),
                accentPrimary: Color(hex: "DADADA"),
                accentDeep: Color(hex: "F4F4F4"),
                accentSoft: Color(hex: "2C2C2C"),
                controlStrong: Color(hex: "F5F5F5"),
                controlStrongText: Color(hex: "121212"),
                success: Color(hex: "B5B5B5"),
                warning: Color(hex: "CECECE"),
                danger: Color(hex: "EDEDED")
            )
        }

        return OpenZonePalette(
            isDark: false,
            surfaceBase: Color(hex: "F7F7F7"),
            surfacePaper: Color(hex: "F1F1F1"),
            surfaceRaised: Color(hex: "FFFFFF"),
            surfaceSubtle: Color(hex: "EAEAEA"),
            surfaceGalaxyTint: Color(hex: "E2E2E2"),
            textPrimary: Color(hex: "141414"),
            textSecondary: Color(hex: "6E6E6E"),
            textTertiary: Color(hex: "9C9C9C"),
            lineSoft: Color(hex: "E0E0E0"),
            lineStrong: Color(hex: "BEBEBE"),
            accentPrimary: Color(hex: "2B2B2B"),
            accentDeep: Color(hex: "0F0F0F"),
            accentSoft: Color(hex: "E2E2E2"),
            controlStrong: Color(hex: "141414"),
            controlStrongText: Color(hex: "FFFFFF"),
            success: Color(hex: "4A4A4A"),
            warning: Color(hex: "333333"),
            danger: Color(hex: "1A1A1A")
        )
    }
}
