import SwiftUI

/// Collapsible reasoning card — streams monospace text while the model thinks.
struct ChatReasoningCardView: View {
    let content: String
    let isComplete: Bool
    let isStreaming: Bool

    @Environment(\.sharedPalette) private var palette
    /// Collapsed by default; auto-expands while reasoning is actively streaming,
    /// then collapses again once thinking completes. User can toggle manually anytime.
    @State private var isExpanded: Bool
    @State private var didAutoCollapse = false

    init(content: String, isComplete: Bool, isStreaming: Bool) {
        self.content = content
        self.isComplete = isComplete
        self.isStreaming = isStreaming
        _isExpanded = State(initialValue: isStreaming)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if showsStreamingBody {
                streamingBody
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceRaised.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.textTertiary.opacity(0.12), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard showsStreamingBody else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
        .onChange(of: isStreaming) { _, streaming in
            // Auto-collapse once thinking finishes (only once; respects later manual toggles).
            guard !streaming, !didAutoCollapse else { return }
            didAutoCollapse = true
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded = false
            }
        }
    }

    private var showsStreamingBody: Bool {
        isStreaming || !content.isEmpty
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)
                .accessibilityHidden(true)

            Text(isComplete ? "Thought" : "Thinking")
                .font(SharedOpenZoneTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
                .monoTracking()

            if isStreaming {
                ChatReasoningPulseDot()
            }

            Spacer(minLength: 8)

            if showsStreamingBody {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
    }

    @ViewBuilder
    private var streamingBody: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(displayedContent)
                .font(SharedOpenZoneTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.08), value: content.count)

            if isStreaming {
                Text("▍")
                    .font(SharedOpenZoneTypography.monoSM)
                    .foregroundStyle(palette.accentPrimary)
                    .opacity(streamingCursorOpacity)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
        .opacity(isExpanded ? 1 : 0)
        .clipped()
        .accessibilityHidden(!isExpanded)
        .onAppear {
            guard isStreaming else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                streamingCursorOpacity = 0.2
            }
        }
    }

    private var displayedContent: String {
        if !content.isEmpty {
            return content
        }
        return isStreaming ? "…" : ""
    }

    @State private var streamingCursorOpacity = 1.0
}

extension ChatReasoningCardView {
    init(message: ChatThinkingMessage) {
        self.init(
            content: message.content,
            isComplete: message.isComplete,
            isStreaming: !message.isComplete
        )
    }
}

private struct ChatReasoningPulseDot: View {
    @Environment(\.sharedPalette) private var palette
    @State private var opacity = 0.35

    var body: some View {
        Circle()
            .fill(palette.accentPrimary)
            .frame(width: 6, height: 6)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    opacity = 1
                }
            }
    }
}
