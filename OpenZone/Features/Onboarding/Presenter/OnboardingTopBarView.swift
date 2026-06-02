import ComposableArchitecture
import SwiftUI

/// Top bar with theme toggle, identity lock-up, page counter, skip button.
struct OnboardingTopBarView: View {
    let store: StoreOf<OnboardingFeature>
    let onThemeToggle: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                ThemeToggleButton(onTap: onThemeToggle)

                VStack(alignment: .leading, spacing: 1) {
                    Text("OPENZONE")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(palette.textPrimary)
                    Text("AI ASSISTANCE")
                        .font(OpenZoneTypography.monoXS)
                        .monoTracking()
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("OpenZone AI assistance")

            Spacer(minLength: 10)

            Text("PG.\(zeroPadded(store.currentPage + 1)) / \(zeroPadded(store.totalPages))")
                .font(OpenZoneTypography.monoSM)
                .monoTracking()
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Button {
                _ = store.send(.skipButtonTapped)
            } label: {
                Text("SKIP")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monoTracking()
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(palette.surfaceSubtle.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(palette.lineSoft, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip onboarding")
        }
        .frame(height: 44)
    }

    private func zeroPadded(_ value: Int) -> String {
        let text = String(value)
        return text.count == 1 ? "0\(text)" : text
    }
}
