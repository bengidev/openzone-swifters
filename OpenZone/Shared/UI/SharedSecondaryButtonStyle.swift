import SwiftUI

/// Secondary action button — transparent/paper fill with cool border.
struct SharedSecondaryButtonStyle: ButtonStyle {
    let palette: SharedOpenZonePalette

    init(palette: SharedOpenZonePalette) {
        self.palette = palette
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .monoTracking()
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.surfaceRaised.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(palette.lineSoft, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
