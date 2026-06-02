import SwiftUI

/// Card container with thin cool borders, quiet fills, restrained radius.
/// Instrument panel aesthetic — no heavy shadows.
public struct CardChrome<Content: View>: View {
    var cornerRadius: CGFloat = 12
    @ViewBuilder let content: Content

    @Environment(\.palette) private var palette

    public init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.surfacePaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.lineSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
