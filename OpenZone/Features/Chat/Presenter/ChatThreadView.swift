import ComposableArchitecture
import SwiftUI

struct ChatThreadView: View {
    @Bindable var store: StoreOf<ChatFeature>

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(store.messages) { message in
                    ChatMessageRowView(
                        message: message,
                        isLastAssistantMessage: isLastAssistantMessage(message),
                        streamingStatus: store.streamingStatus,
                        streamErrorMessage: store.streamErrorMessage
                    )
                    .id(message.id)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(palette.surfaceBase)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .background(palette.surfaceBase)
            .onChange(of: store.messages.count) { _, _ in
                scrollToLast(proxy: proxy, animate: true)
            }
            .onChange(of: store.currentPartialText.count) { _, _ in
                scrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: store.currentPartialThinking.count) { _, _ in
                scrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: store.streamingStatus) { _, _ in
                scrollToLast(proxy: proxy, animate: true)
            }
        }
    }

    private func isLastAssistantMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              let lastAssistantIndex = store.messages.lastIndex(where: { $0.role == .assistant })
        else { return false }
        return store.messages[lastAssistantIndex].id == message.id
    }

    private func scrollToLast(proxy: ScrollViewProxy, animate: Bool) {
        // The reasoning row is now an item-scoped message in `store.messages`
        // (see ChatFeature.streamingThinkingID), so the last message id is
        // always the correct scroll anchor — no separate live-stream row.
        guard let scrollTarget = store.messages.last?.id else { return }

        if animate {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(scrollTarget, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(scrollTarget, anchor: .bottom)
        }
    }
}
