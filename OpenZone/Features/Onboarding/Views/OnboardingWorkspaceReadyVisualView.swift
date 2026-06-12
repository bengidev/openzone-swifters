import SwiftUI

/// Workspace ready page — large title, feature badges, final CTA moment.
struct OnboardingWorkspaceReadyVisualView: View {
    let page: OnboardingPage
    let appeared: Bool

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Status chip
                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.accentPrimary)
                        .frame(width: 7, height: 7)
                        .shadow(color: palette.accentPrimary.opacity(0.45), radius: 8)

                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)

                    Text("WORKSPACE READY")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monoTracking()
                        .foregroundStyle(palette.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.surfaceSubtle.opacity(0.5))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(palette.lineSoft, lineWidth: 1)
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.05), value: appeared)

                // Large product name
                Text(page.headline)
                    .font(SharedOpenZoneTypography.displayXL)
                    .displayTracking()
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.12), value: appeared)

                // Supporting copy
                Text(page.body)
                    .font(SharedOpenZoneTypography.bodyLG)
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.82)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.52, dampingFraction: 0.8).delay(0.20), value: appeared)

                // Feature badges
                HStack(spacing: 6) {
                    ForEach(Array(page.highlights.enumerated()), id: \.element.id) { index, highlight in
                        Text(highlight.title.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monoTracking()
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(palette.surfaceSubtle.opacity(0.3))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(palette.lineSoft, lineWidth: 1)
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(.spring(response: 0.48, dampingFraction: 0.8).delay(0.28 + Double(index) * 0.04), value: appeared)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
