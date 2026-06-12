import SwiftUI

/// Primary action button — graphite fill, high contrast, for commit/continue/enter actions.
struct SharedPrimaryButtonStyle: ButtonStyle {
    let palette: SharedOpenZonePalette

    init(palette: SharedOpenZonePalette) {
        self.palette = palette
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .monoTracking()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(palette.controlStrongText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.controlStrong)
                    .opacity(configuration.isPressed ? 0.92 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
