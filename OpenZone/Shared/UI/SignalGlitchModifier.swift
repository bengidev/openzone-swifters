import SwiftUI

/// Subtle RGB shift overlay with sine wave offset — technical signal glitch effect.
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
                                Color.red.opacity(0.06 * intensity),
                                Color.clear,
                                Color.blue.opacity(0.06 * intensity),
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
