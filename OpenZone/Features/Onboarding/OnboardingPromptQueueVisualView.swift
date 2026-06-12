import SwiftUI

/// Prompt queue demo — staggered row animations, status indicators.
struct OnboardingPromptQueueVisualView: View {
    let queuedPromptCount: Int
    let appeared: Bool

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 9) {
            ForEach(Array(OnboardingQueueItem.samples.prefix(queuedPromptCount).enumerated()), id: \.element.id) { index, item in
                OnboardingQueueRowView(item: item, index: index, appeared: appeared)
            }

            Color.clear
                .frame(height: 16)
                .id("queueLast")
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
