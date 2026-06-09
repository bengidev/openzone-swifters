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
        var pinned: [(id: UUID, value: Bool)] = []
        var renamed: [(id: UUID, title: String)] = []
        var deleted: [UUID] = []

        init(_ seed: [ChatConversation]) { self.conversations = seed }

        func list() -> [ChatConversation] { conversations }
        func setPinned(_ id: UUID, _ value: Bool) { pinned.append((id, value)) }
        func rename(_ id: UUID, _ title: String) { renamed.append((id, title)) }
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
            renameConversation: { await recorder.rename($0, $1) }
        )
    }

    private func conversation(
        _ title: String,
        id: UUID = UUID(),
        pinned: Bool = false
    ) -> ChatConversation {
        ChatConversation(id: id, title: title, isPinned: pinned)
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

    @Test("Pinning persists the toggle then reloads the authoritative order")
    func pinPersistsAndReloads() async {
        let target = conversation("Pin me")
        let recorder = Recorder([target])
        let store = makeStore(
            recorder: recorder,
            state: .init(conversations: [target])
        )

        await store.send(.conversationPinToggled(target))
        await store.receive(\.conversationsLoaded)
        #expect(await recorder.pinned.map(\.value) == [true])
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
        #expect(await recorder.deleted == [id])
    }
}
