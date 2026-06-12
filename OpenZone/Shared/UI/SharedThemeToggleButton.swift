import SwiftUI

/// Theme toggle control — cycles through system/light/dark with sliding thumb animation.
struct SharedThemeToggleButton: View {
    let onTap: () -> Void

    @Environment(\.sharedPalette) private var palette
    @Environment(\.sharedAppTheme) private var appTheme
    @State private var tapped = false

    private var isSystemMode: Bool {
        appTheme == .system
    }

    private var resolvedIsDark: Bool {
        palette.isDark
    }

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    var body: some View {
        ZStack {
            // Track
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(0.5))
                .frame(width: 32, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isSystemMode ? palette.lineStrong : palette.lineSoft,
                            lineWidth: isSystemMode ? 0.8 : 0.5
                        )
                )

            // Sliding thumb
            HStack {
                if resolvedIsDark, !isSystemMode {
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.accentPrimary)
                    .frame(width: 11, height: 22)
                    .shadow(
                        color: palette.accentPrimary.opacity(isSystemMode ? 0.30 : 0.50),
                        radius: isSystemMode ? 2 : 4,
                        x: 0,
                        y: 2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(
                                isSystemMode
                                    ? palette.textPrimary.opacity(0.08)
                                    : palette.textPrimary.opacity(0.18),
                                lineWidth: 0.5
                            )
                    )
                    .padding(.horizontal, isSystemMode ? 11 : 3)
                    .scaleEffect(tapped ? 0.88 : 1.0)
                    .rotationEffect(.degrees(tapped ? -8 : 0))

                if !resolvedIsDark, !isSystemMode {
                    Spacer()
                }
            }
            .frame(width: 32, height: 28)
        }
        .frame(width: 32, height: 28)
        .scaleEffect(tapped ? 0.94 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                tapped = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    tapped = false
                    onTap()
                }
            }
        }
    }
}
