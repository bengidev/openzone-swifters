import SwiftUI

/// Preset button for reasoning level — FAST / BALANCED / DEEP.
struct OnboardingReasoningPresetButtonView: View {
    let title: String
    let value: Double
    @Binding var level: Double

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                level = value
            }
        } label: {
            Text(title)
                .font(SharedOpenZoneTypography.monoXS)
                .monoTracking()
                .foregroundStyle(abs(level - value) < 0.08 ? palette.controlStrongText : palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(abs(level - value) < 0.08 ? palette.controlStrong : palette.surfaceSubtle.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(abs(level - value) < 0.08 ? palette.controlStrong.opacity(0.3) : palette.lineSoft, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
