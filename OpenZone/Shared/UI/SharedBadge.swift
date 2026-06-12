import SwiftUI

/// Eyebrow badge — compact chip for capability/state introduction.
/// Uses mono text, optional icon, blue dot for active state.
struct SharedBadge: View {
    let title: String
    var systemImage: String?
    var isActive: Bool = false

    @Environment(\.sharedPalette) private var palette

    init(title: String, systemImage: String? = nil, isActive: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isActive ? palette.accentPrimary : palette.textTertiary)
                .frame(width: 5, height: 5)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title.uppercased())
                .font(SharedOpenZoneTypography.monoXS)
                .monoTracking()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .foregroundStyle(isActive ? palette.accentPrimary : palette.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(palette.surfaceSubtle.opacity(0.5))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isActive ? palette.accentPrimary.opacity(0.4) : palette.lineSoft, lineWidth: 1)
        )
    }
}
