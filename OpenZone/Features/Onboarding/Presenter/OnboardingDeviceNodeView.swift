import SwiftUI

/// Device card for pairing visualization.
struct OnboardingDeviceNodeView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let active: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(0.5))
                    .frame(width: 76, height: 92)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(active ? palette.accentPrimary.opacity(0.52) : palette.lineSoft, lineWidth: 1)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(active ? palette.textPrimary : palette.textTertiary)
            }
            VStack(spacing: 3) {
                Text(title)
                    .font(OpenZoneTypography.monoXS)
                    .monoTracking()
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 108)
    }
}
