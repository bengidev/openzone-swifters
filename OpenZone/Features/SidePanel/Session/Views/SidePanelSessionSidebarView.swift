import ComposableArchitecture
import SwiftUI

/// Sliding history drawer listing persisted conversations, grouped into a
/// Pinned section followed by recency buckets (Today, Yesterday, Previous 7
/// Days, Previous 30 Days, Older). A search field filters by title; each row
/// offers a long-press menu to rename, pin/unpin, or delete. Tapping a row
/// emits a session delegate so the parent reopens the conversation in the chat
/// reducer. All colors are sourced from the shared palette.
struct SidePanelSessionSidebarView: View {
    @Bindable var store: StoreOf<SidePanelSessionFeature>

    @Environment(\.sharedPalette) private var palette

    @State private var renameTarget: ChatConversation?
    @State private var renameText: String = ""

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
        .alert("Rename conversation", isPresented: renameAlertBinding) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let target = renameTarget {
                    store.send(.conversationRenamed(id: target.id, title: renameText))
                }
                renameTarget = nil
            }
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
            searchField
            Divider()
                .overlay(palette.textTertiary.opacity(0.25))

            if store.conversations.isEmpty {
                emptyState
            } else if store.filteredConversations.isEmpty {
                noResultsState
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
        HStack(spacing: 12) {
            Text("History")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("sidepanel-settings-button")
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
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField(
                "Search conversations",
                text: Binding(
                    get: { store.historySearchQuery },
                    set: { store.send(.historySearchQueryChanged($0)) }
                )
            )
            .font(.system(size: 15))
            .foregroundStyle(palette.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !store.historySearchQuery.isEmpty {
                Button {
                    store.send(.historySearchQueryChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous).fill(palette.surfaceSubtle)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        centeredState(
            icon: "bubble.left.and.bubble.right",
            title: "No conversations yet",
            subtitle: "Your chats will appear here."
        )
    }

    private var noResultsState: some View {
        centeredState(
            icon: "magnifyingglass",
            title: "No matches",
            subtitle: "No conversations match your search."
        )
    }

    private func centeredState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                ForEach(SidePanelSessionSection.grouped(store.filteredConversations)) { section in
                    Section {
                        ForEach(section.conversations) { conversation in
                            Button {
                                store.send(.conversationSelected(conversation))
                            } label: {
                                conversationRow(conversation)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { rowMenu(conversation) }
                        }
                    } header: {
                        sectionHeader(section.title)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .background(palette.surfacePaper)
    }

    @ViewBuilder
    private func rowMenu(_ conversation: ChatConversation) -> some View {
        Button {
            renameText = conversation.title
            renameTarget = conversation
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            store.send(.conversationPinToggled(conversation))
        } label: {
            Label(
                conversation.isPinned ? "Unpin" : "Pin",
                systemImage: conversation.isPinned ? "pin.slash" : "pin"
            )
        }
        Button(role: .destructive) {
            store.send(.conversationDeleted(conversation.id))
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        let isActive = store.activeConversationID == conversation.id
        return HStack(spacing: 8) {
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
            }
            Text(conversation.title)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Text(SidePanelSessionSection.relativeLabel(for: conversation.updatedAt))
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
                .fixedSize()
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

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private func drawerWidth(for totalWidth: CGFloat) -> CGFloat {
        min(totalWidth * drawerWidthRatio, maxDrawerWidth)
    }
}
