import ComposableArchitecture
import SwiftUI

/// Sliding history drawer listing persisted conversations. Tapping a row hands
/// off to `HomeFeature` which closes the drawer and reopens the conversation in
/// the chat reducer. All colors are sourced from the shared palette.
struct ChatHistorySidebarView: View {
    @Bindable var store: StoreOf<HomeFeature>

    @Environment(\.palette) private var palette

    private let drawerWidthRatio: CGFloat = 0.82
    private let maxDrawerWidth: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if store.isSidebarVisible {
                    scrim
                    drawer(width: drawerWidth(for: proxy.size.width))
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.easeInOut(duration: 0.28), value: store.isSidebarVisible)
        }
    }

    private var scrim: some View {
        palette.textPrimary
            .opacity(0.32)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { store.send(.sidebarDismissed) }
            .accessibilityLabel("Dismiss sidebar")
            .accessibilityAddTraits(.isButton)
    }

    private func drawer(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .overlay(palette.textTertiary.opacity(0.25))

            if store.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(palette.surfacePaper)
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack {
            Text("History")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Button {
                store.send(.sidebarDismissed)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            .accessibilityLabel("Close history")
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.textTertiary)
            Text("No conversations yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text("Your chats will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(store.conversations) { conversation in
                    Button {
                        store.send(.conversationSelected(conversation))
                    } label: {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        let isActive = store.chat.conversation?.id == conversation.id
        return VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
            Text(conversation.updatedAt, format: .relative(presentation: .named))
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? palette.surfaceSubtle : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityIdentifier("history-conversation-row")
    }

    private func drawerWidth(for totalWidth: CGFloat) -> CGFloat {
        min(totalWidth * drawerWidthRatio, maxDrawerWidth)
    }
}
