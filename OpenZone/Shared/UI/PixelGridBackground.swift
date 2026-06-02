import SwiftUI

/// Subtle dot grid background — cool technical texture.
public struct PixelGridBackground: View {
    var spacing: CGFloat = 20
    var dotSize: CGFloat = 1.0
    var opacity = 0.05

    @Environment(\.palette) private var palette

    public init(spacing: CGFloat = 20, dotSize: CGFloat = 1.0, opacity: Double = 0.05) {
        self.spacing = spacing
        self.dotSize = dotSize
        self.opacity = opacity
    }

    public var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(palette.textPrimary.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
