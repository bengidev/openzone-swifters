import SwiftUI

/// Idea Studio demo — prompt chips, typewriter effect, response lines.
struct OnboardingIdeaStudioVisualView: View {
    let selectedPromptIndex: Int
    let appeared: Bool
    let onPromptSelected: (Int) -> Void

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typedCount = 0

    private var prompt: String {
        OnboardingPromptOption.samples[selectedPromptIndex].prompt
    }

    var body: some View {
        VStack(spacing: 10) {
            // Prompt chips — ASK / WRITE / EXPLORE
            HStack(spacing: 7) {
                ForEach(Array(OnboardingPromptOption.samples.enumerated()), id: \.element.id) { index, option in
                    Button {
                        onPromptSelected(index)
                    } label: {
                        Text(option.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(-0.24)
                            .foregroundStyle(index == selectedPromptIndex ? palette.controlStrongText : palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(index == selectedPromptIndex ? palette.controlStrong : palette.surfaceSubtle.opacity(0.4))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select prompt mode \(option.label)")
                }
            }

            // Prompt input with typewriter + response lines
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(">")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.accentPrimary)
                    Text(String(prompt.prefix(typedCount)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Rectangle()
                        .fill(palette.textPrimary)
                        .frame(width: 6, height: 15)
                        .opacity(typedCount < prompt.count ? 1 : 0.34)
                }

                VStack(alignment: .leading, spacing: 6) {
                    OnboardingResponseLineView(width: 0.84, active: appeared, delay: 0)
                    OnboardingResponseLineView(width: 0.62, active: appeared, delay: 0.07)
                    OnboardingResponseLineView(width: 0.74, active: appeared, delay: 0.14)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.surfaceBase.opacity(palette.isDark ? 0.5 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(palette.lineSoft, lineWidth: 1)
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .task(id: prompt) {
            await animateTyping()
        }
    }

    @MainActor
    private func animateTyping() async {
        typedCount = reduceMotion ? prompt.count : 0
        guard !reduceMotion else { return }

        for count in 0...prompt.count {
            typedCount = count
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
}
