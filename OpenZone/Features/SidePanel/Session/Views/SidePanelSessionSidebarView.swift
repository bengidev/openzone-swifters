import ComposableArchitecture
import SwiftUI

/// Sliding history drawer listing persisted conversations, grouped into a
/// Pinned section followed by user-defined groups and recency buckets
/// (Today, Yesterday, Previous 7 Days, Previous 30 Days, Older). A search
/// field filters by title; each row offers a long-press menu to pin,
/// group, or delete. Tapping a row emits a session delegate so the parent
/// reopens the conversation in the chat reducer. All colors are sourced
/// from the shared palette.
struct SidePanelSessionSidebarView: View {
    @Bindable var store: StoreOf<SidePanelSessionFeature>

    @Environment(\.sharedPalette) private var palette

    @State private var renameTarget: ChatConversation?
    @State private var renameText: String = ""
    @State private var newGroupText: String = ""
    @State private var newGroupTargetID: UUID?

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
        .alert("Create Group", isPresented: Binding(
            get: { newGroupTargetID != nil },
            set: { if !$0 { newGroupTargetID = nil } }
        )) {
            TextField("Group name", text: $newGroupText)
            Button("Cancel", role: .cancel) {
                newGroupTargetID = nil
            }
            Button("Create") {
                if let targetID = newGroupTargetID {
                    let trimmed = newGroupText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        store.send(.conversationGroupChanged(id: targetID, group: trimmed))
                    }
                    newGroupTargetID = nil
                }
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
        ScrollView(.vertical) {
            conversationListContent
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    /// Busts LazyVStack identity when pin/group state changes so rows move between
    /// sections immediately instead of only after the drawer is reopened.
    private var sessionListIdentity: String {
        store.conversations
            .map { "\($0.id.uuidString):\($0.isPinned):\($0.groupName ?? "")" }
            .joined(separator: "|")
    }

    private func liveConversation(id: UUID) -> ChatConversation? {
        store.conversations.first { $0.id == id }
    }

    @ViewBuilder
    private var conversationListContent: some View {
        LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
            ForEach(SidePanelSessionSection.grouped(
                store.filteredConversations,
                expandedGroups: store.expandedGroups,
                forceExpandGroups: !store.historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )) { section in
                Section {
                    ForEach(section.conversations) { conversation in
                        Button {
                            let live = liveConversation(id: conversation.id) ?? conversation
                            store.send(.conversationSelected(live))
                        } label: {
                            conversationRow(
                                conversation,
                                isInGroup: section.id.hasPrefix("group:")
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu { rowMenu(conversation) }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id("\(section.id)-\(conversation.id)")
                    }
                } header: {
                    groupSectionHeader(section)
                }
            }
        }
        .id(sessionListIdentity)
    }

    @ViewBuilder
    private func groupSectionHeader(_ section: SidePanelSessionSection) -> some View {
        if section.id.hasPrefix("group:") {
            let groupName = String(section.id.dropFirst("group:".count))
            let isExpanded = store.expandedGroups.contains(groupName)
            Button {
                _ = withAnimation(.easeInOut(duration: 0.22)) {
                    store.send(.groupHeaderToggled(groupName))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.accentSoft)
                    Text(groupName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            sectionHeader(section.title)
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
        let live = liveConversation(id: conversation.id) ?? conversation
        Button {
            renameTarget = live
            renameText = live.title
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            _ = withAnimation(.easeInOut(duration: 0.22)) {
                store.send(.conversationPinToggled(live))
            }
        } label: {
            Label(
                live.isPinned ? "Unpin" : "Pin",
                systemImage: live.isPinned ? "pin.slash" : "pin"
            )
        }
        Menu {
            ForEach(store.availableGroups, id: \.self) { group in
                Button(group) {
                    store.send(.conversationGroupChanged(
                        id: live.id,
                        group: live.groupName == group ? nil : group
                    ))
                }
            }
            if let currentGroup = live.groupName {
                Button(role: .destructive) {
                    store.send(.conversationGroupChanged(id: live.id, group: nil))
                } label: {
                    Label("Remove from \(currentGroup)", systemImage: "folder.badge.minus")
                }
            }
            Divider()
            Button {
                newGroupTargetID = live.id
                newGroupText = ""
            } label: {
                Label("New Group...", systemImage: "folder.badge.plus")
            }
        } label: {
            Label(
                live.groupName == nil ? "Move to Group" : "Group: \(live.groupName!)",
                systemImage: "folder"
            )
        }
        Button(role: .destructive) {
            store.send(.conversationDeleted(live.id))
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func conversationRow(
        _ conversation: ChatConversation,
        isInGroup: Bool
    ) -> some View {
        let live = liveConversation(id: conversation.id) ?? conversation
        let isActive = store.activeConversationID == live.id
        return HStack(spacing: 8) {
            if live.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
            }
            if !isInGroup, live.groupName != nil {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accentSoft)
            }
            Text(live.title)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Text(SidePanelSessionSection.relativeLabel(for: live.updatedAt))
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, isInGroup ? 18 : 0)
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
