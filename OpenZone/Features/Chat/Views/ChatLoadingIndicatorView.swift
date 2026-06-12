import SwiftUI

/// Chat-bubble typing indicator shown while streaming is running but no
/// assistant message or thinking row has been created yet. Three dots
/// animate with a staggered pulse, matching the assistant row's alignment
/// and spacing so the loading state flows seamlessly into the streamed
/// response.
struct ChatLoadingIndicatorView: View {
    @Environment(\.sharedPalette) private var palette
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(palette.textSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(animate ? 0.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.surfaceRaised)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .onAppear { animate = true }
    }
}
