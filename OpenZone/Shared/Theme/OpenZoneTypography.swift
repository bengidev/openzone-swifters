import SwiftUI

/// Typography system for OpenZone — modern, strict, readable.
/// Sans for human-facing text, monospace for technical state.
public enum OpenZoneTypography {

    // MARK: - Display (large, direct, tightly composed)

    /// Final product statement or hero lock-up — 56pt
    public static let displayXL: Font = .system(size: 56, weight: .regular, design: .default)
    /// Mobile onboarding titles — 42pt
    public static let displayLG: Font = .system(size: 42, weight: .regular, design: .default)
    /// Desktop panel titles and section headers — 32pt
    public static let displayMD: Font = .system(size: 32, weight: .regular, design: .default)

    // MARK: - Body (calm, readable, short)

    /// Onboarding support copy — 21pt
    public static let bodyLG: Font = .system(size: 21, weight: .regular, design: .default)
    /// Standard body copy — 16pt
    public static let bodyMD: Font = .system(size: 16, weight: .regular, design: .default)

    // MARK: - Label (compact, durable, high signal)

    /// Buttons and durable labels — 13pt
    public static let labelMD: Font = .system(size: 13, weight: .medium, design: .default)

    // MARK: - Mono (technical, sparse, secondary)

    /// State codes, page counts, tabs, technical labels — 12pt
    public static let monoSM: Font = .system(size: 12, weight: .medium, design: .monospaced)
    /// Dense metadata only — 10pt
    public static let monoXS: Font = .system(size: 10, weight: .medium, design: .monospaced)
}

// MARK: - Tracking (letter spacing)

extension Font {
    /// Tight tracking for display text
    public func tightTracking() -> Font {
        self // SwiftUI doesn't expose tracking on Font, apply via .tracking() modifier
    }
}

extension View {
    /// Apply tight tracking for display headlines
    public func displayTracking() -> some View {
        self.tracking(-0.04)
    }

    /// Apply mono tracking for technical labels
    public func monoTracking() -> some View {
        self.tracking(0.04)
    }
}
