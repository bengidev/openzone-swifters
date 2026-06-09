import ComposableArchitecture
import SwiftUI

/// A persistent failure banner shown when a chat turn errors (missing/invalid
/// key, HTTP 401, network failure, mid-stream error). It renders independently
/// of the message rows so a connection failure that never produced an assistant
/// row still surfaces visible feedback — the gap that previously let errors
/// fail silently. Offers Retry (re-issue the last request) and Dismiss.
struct ChatErrorBannerView: View {
    @Bindable var store: StoreOf<ChatFeature>

    @Environment(\.palette) private var palette

    var body: some View {
        if store.streamingStatus == .failed, let message = store.streamErrorMessage {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.danger)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn’t get a response")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(message)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        store.send(.retryTapped)
                    } label: {
                        Text("Retry")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.controlStrongText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(palette.controlStrong)
                            )
                    }
                    .accessibilityLabel("Retry sending the message")

                    Button {
                        store.send(.errorDismissed)
                    } label: {
                        Text("Dismiss")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .accessibilityLabel("Dismiss error")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.lineStrong, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chat-error-banner")
        }
    }
}
