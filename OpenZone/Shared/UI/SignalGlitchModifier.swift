import SwiftUI

/// Subtle monochrome luminance shift overlay with sine wave offset — technical signal glitch effect.
public struct SignalGlitchModifier: ViewModifier {
    let progress: Double
    let intensity: Double

    public func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07 * intensity),
                                Color.clear,
                                Color.white.opacity(0.04 * intensity),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .offset(x: sin(progress * .pi * 4) * 0.5 * intensity)
    }
}

extension View {
    public func signalGlitch(progress: Double, intensity: Double = 1) -> some View {
        modifier(SignalGlitchModifier(progress: progress, intensity: intensity))
    }
}
