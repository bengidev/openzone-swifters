import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Reducer-level tests for the side panel's session scope. These pin down the
/// behavior that used to live inside `HomeFeature` before the side panel became
/// a self-contained module: list loading on open, local title filtering,
/// pin/rename/delete persistence, and the delegate outputs the parent relies on
/// to drive the live chat reducer. A recording stub `ChatHistoryClient` lets us
/// assert exactly which writes happen without SwiftData.
@MainActor
@Suite("Side Panel Session Feature")
struct SidePanelSessionFeatureTests {

    /// A recording history client backed by an actor so the `@Sendable`
    /// closures can capture mutations safely under strict concurrency.
    private actor Recorder {
        var conversations: [ChatConversation]
        var groups: [String]
        var pinned: [(id: UUID, value: Bool)] = []
        var renamed: [(id: UUID, title: String)] = []
        var grouped: [(id: UUID, group: String?)] = []
        var deleted: [UUID] = []

        init(_ seed: [ChatConversation], groups: [String] = []) {
            self.conversations = seed
            self.groups = groups
        }

        func list() -> [ChatConversation] { conversations }
        func listGroups() -> [String] { groups }
        func setPinned(_ id: UUID, _ value: Bool) { pinned.append((id, value)) }
        func rename(_ id: UUID, _ title: String) { renamed.append((id, title)) }
        func setGroup(_ id: UUID, _ group: String?) { grouped.append((id, group)) }
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private func makeClient(_ recorder: Recorder) -> ChatHistoryClient {
        ChatHistoryClient(
            listConversations: { await recorder.list() },
            loadMessages: { _ in [] },
            saveConversation: { _ in },
            appendMessage: { _, _ in },
            deleteConversation: { await recorder.delete($0) },
            setPinned: { await recorder.setPinned($0, $1) },
            renameConversation: { await recorder.rename($0, $1) },
            setGroup: { await recorder.setGroup($0, $1) },
            listGroups: { await recorder.listGroups() }
        )
    }

    private func conversation(
        _ title: String,
        id: UUID = UUID(),
        pinned: Bool = false,
        groupName: String? = nil
    ) -> ChatConversation {
        ChatConversation(id: id, title: title, isPinned: pinned, groupName: groupName)
    }

    private func makeStore(
        recorder: Recorder,
        state: SidePanelSessionFeature.State = .init()
    ) -> TestStoreOf<SidePanelSessionFeature> {
        TestStore(initialState: state) {
            SidePanelSessionFeature()
        } withDependencies: {
            $0[ChatHistoryClient.self] = makeClient(recorder)
        }
    }

    @Test("Opening the drawer loads the persisted conversation list")
    func toggleLoadsConversations() async {
        let seed = [conversation("Alpha"), conversation("Beta")]
        let recorder = Recorder(seed)
        let store = makeStore(recorder: recorder)
        await store.send(.sidebarToggleTapped) {
            $0.isSidebarVisible = true
        }
        await store.receive(\.conversationsLoaded) {
            $0.conversations = seed
        }
        await store.receive(\.groupsLoaded)
    }

    @Test("Closing the drawer does not reload")
    func toggleClosedSkipsReload() async {
        let recorder = Recorder([])
        let store = makeStore(
            recorder: recorder,
            state: .init(isSidebarVisible: true)
        )

        await store.send(.sidebarToggleTapped) {
            $0.isSidebarVisible = false
        }
        // No `.conversationsLoaded` effect when collapsing.
    }

    @Test("Search query filters the loaded list by title, case-insensitively")
    func searchFilters() async {
        let recorder = Recorder([])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [conversation("Swift tips"), conversation("Dinner ideas")])
        )

        await store.send(.historySearchQueryChanged("swift")) {
            $0.historySearchQuery = "swift"
        }
        #expect(store.state.filteredConversations.map(\.title) == ["Swift tips"])
    }

    @Test("Selecting a conversation closes the drawer and delegates open")
    func selectDelegatesOpen() async {
        let target = conversation("Reopen me")
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(isSidebarVisible: true, conversations: [target])
        )

        await store.send(.conversationSelected(target)) {
            $0.isSidebarVisible = false
        }
        await store.receive(\.delegate.openConversation)
    }

    @Test("Pinning toggles state optimistically then persists fire-and-forget")
    func pinOptimisticUpdate() async {
        let target = conversation("Pin me")
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target])
        )

        store.exhaustivity = .off
        await store.send(.conversationPinToggled(target))
        #expect(store.state.conversations.first?.isPinned == true)
        #expect(await recorder.pinned.count == 1)
        #expect(await recorder.pinned.map(\.value) == [true])
    }

    @Test("Unpinning toggles state optimistically then persists fire-and-forget")
    func unpinOptimisticUpdate() async {
        let target = conversation("Unpin me", pinned: true)
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target])
        )

        store.exhaustivity = .off
        await store.send(.conversationPinToggled(target))
        #expect(store.state.conversations.first?.isPinned == false)
        #expect(await recorder.pinned.map(\.value) == [false])
    }

    @Test("Pinning re-sorts conversations pinned-first")
    func pinResortsPinnedFirst() async {
        let unpinned = conversation("Later", id: UUID())
        let target = conversation("Pin me")
        let recorder = Recorder([unpinned, target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [unpinned, target])
        )

        store.exhaustivity = .off
        await store.send(.conversationPinToggled(target))
        #expect(store.state.conversations.map(\.title) == ["Pin me", "Later"])
    }

    @Test("Renaming the active conversation delegates the new title")
    func renameActiveDelegates() async {
        let id = UUID()
        let target = conversation("Old", id: id)
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: id)
        )

        await store.send(.conversationRenamed(id: id, title: "New"))
        await store.receive(\.delegate.activeConversationRenamed)
        await store.receive(\.conversationsLoaded)
        #expect(await recorder.renamed.map(\.title) == ["New"])
    }

    @Test("Renaming a non-active conversation persists without delegating")
    func renameInactiveNoDelegate() async {
        let id = UUID()
        let target = conversation("Old", id: id)
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )

        await store.send(.conversationRenamed(id: id, title: "New"))
        await store.receive(\.conversationsLoaded)
        #expect(await recorder.renamed.map(\.title) == ["New"])
    }

    @Test("Deleting the active conversation delegates a clear")
    func deleteActiveDelegates() async {
        let id = UUID()
        let target = conversation("Doomed", id: id)
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: id)
        )

        await store.send(.conversationDeleted(id))
        await store.receive(\.delegate.activeConversationDeleted)
        await store.receive(\.conversationsLoaded)
        await store.receive(\.groupsLoaded)
        #expect(await recorder.deleted == [id])
    }

    @Test("Deleting a non-active conversation persists without delegating")
    func deleteInactiveNoDelegate() async {
        let id = UUID()
        let target = conversation("Doomed", id: id)
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )

        await store.send(.conversationDeleted(id))
        await store.receive(\.conversationsLoaded)
        await store.receive(\.groupsLoaded)
        #expect(await recorder.deleted == [id])
    }

    @Test("Deleting reloads available groups")
    func deleteReloadsGroups() async {
        let id = UUID()
        let target = conversation("Doomed", id: id, groupName: "Work")
        let recorder = Recorder([target], groups: ["Archive"])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )

        await store.send(.conversationDeleted(id))
        await store.receive(\.conversationsLoaded)
        await store.receive(\.groupsLoaded) {
            $0.availableGroups = ["Archive"]
        }
        #expect(await recorder.deleted == [id])
    }

    @Test("Grouping a conversation persists the group assignment")
    func groupChangePersistsAndReloads() async throws {
        let target = conversation("To Group")
        let recorder = Recorder([target])
        let store = makeStore(recorder: recorder, state: .init(conversations: [target]))

        await store.send(.conversationGroupChanged(id: target.id, group: "Work")) {
            $0.expandedGroups.insert("Work")
        }
        await store.receive(\.conversationsLoaded)
        await store.receive(\.groupsLoaded)
        #expect(await recorder.grouped.count == 1)
        #expect(await recorder.grouped.first?.id == target.id)
        #expect(await recorder.grouped.first?.group == "Work")
    }

    @Test("Group header toggle expands/collapses")
    func groupHeaderExpandCollapse() async throws {
        let recorder = Recorder([])
        let store = makeStore(recorder: recorder, state: .init())

        await store.send(.groupHeaderToggled("Work")) {
            $0.expandedGroups.insert("Work")
        }
        await store.send(.groupHeaderToggled("Work")) {
            $0.expandedGroups.remove("Work")
        }
    }

    @Test("Removing a group sets groupName to nil")
    func removeGroup() async throws {
        let target = conversation("Grouped", groupName: "Work")
        let recorder = Recorder([target])
        let store = makeStore(recorder: recorder, state: .init(conversations: [target]))

        await store.send(.conversationGroupChanged(id: target.id, group: nil))
        await store.receive(\.conversationsLoaded)
        await store.receive(\.groupsLoaded)
        #expect(await recorder.grouped.count == 1)
        #expect(await recorder.grouped.first?.id == target.id)
        #expect(await recorder.grouped.first?.group == nil)
    }

    @Test("filteredConversations deduplicates by id keeping the pinned copy")
    func filteredConversationsDeduplicatesPinnedFirst() {
        let id = UUID()
        let unpinned = ChatConversation(id: id, title: "Unpinned", isPinned: false)
        let pinned = ChatConversation(id: id, title: "Pinned", isPinned: true)
        let state = SidePanelSessionFeature.State(conversations: [unpinned, pinned])
        let result = state.filteredConversations
        #expect(result.count == 1)
        #expect(result[0].title == "Pinned")
        #expect(result[0].isPinned == true)
    }

    @Test("filteredConversations deduplication preserves search filtering")
    func filteredConversationsDeduplicatesWithSearch() {
        let id = UUID()
        let first = ChatConversation(id: id, title: "Swift tips", isPinned: false)
        let second = ChatConversation(id: id, title: "Swift tips dup", isPinned: true)
        var state = SidePanelSessionFeature.State(conversations: [first, second])
        state.historySearchQuery = "swift"
        let result = state.filteredConversations
        #expect(result.count == 1)
        #expect(result[0].title == "Swift tips dup")
        #expect(result[0].isPinned == true)
    }
}
