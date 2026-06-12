import SwiftUI

/// Custom reasoning slider — thumb tracks value; active fill reaches thumb center.
struct OnboardingReasoningLevelSliderView: View {
    @Binding var value: Double

    @Environment(\.sharedPalette) private var palette

    private let thumbWidth: CGFloat = 24
    private let thumbHeight: CGFloat = 20
    private let trackHeight: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let travel = max(width - thumbWidth, 1)
            let fraction = min(max(value, 0), 1)
            let thumbOffset = travel * fraction
            let activeWidth = thumbOffset + thumbWidth / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.lineSoft.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)

                Capsule()
                    .fill(palette.accentPrimary)
                    .frame(width: max(activeWidth, trackHeight), height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(palette.lineSoft, lineWidth: 1)
                    )
                    .frame(width: thumbWidth, height: thumbHeight)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .offset(x: thumbOffset)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(at: gesture.location.x, travel: travel)
                    }
            )
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reasoning level")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }

    private func updateValue(at locationX: CGFloat, travel: CGFloat) {
        let centered = locationX - thumbWidth / 2
        let clamped = min(max(centered, 0), travel)
        value = Double(clamped / travel)
    }
}
