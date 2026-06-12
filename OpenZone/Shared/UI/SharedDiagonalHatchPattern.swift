import SwiftUI

/// Fine diagonal hatch texture — gives UI a physical surface without hurting readability.
/// Low opacity, 45-degree angle, technical paper aesthetic.
struct SharedDiagonalHatchPattern: View {
    var spacing: CGFloat = 12
    var opacity = 0.04

    @Environment(\.sharedPalette) private var palette

    init(spacing: CGFloat = 12, opacity: Double = 0.04) {
        self.spacing = spacing
        self.opacity = opacity
    }

    var body: some View {
        Canvas { context, size in
            for x in stride(from: -size.height, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(
                    path,
                    with: .color(palette.textPrimary.opacity(opacity)),
                    lineWidth: 1
                )
            }
        }
        .allowsHitTesting(false)
    }
}
