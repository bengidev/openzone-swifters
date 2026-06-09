import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

@MainActor
@Suite("Chat History Feature")
struct ChatHistoryFeatureTests {
    @Test("Opening the sidebar loads conversations")
    func sidebarOpenLoadsHistory() async {
        let conversation = ChatConversation(
            id: UUID(0),
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let store = TestStore(initialState: ChatHistoryFeature.State()) {
            ChatHistoryFeature()
        } withDependencies: {
            $0.chatHistoryClient = ChatHistoryClient(
                listConversations: { [conversation] },
                loadMessages: { _ in [] },
                saveConversation: { _ in },
                appendMessage: { _, _ in },
                deleteConversation: { _ in },
                setPinned: { _, _ in },
                renameConversation: { _, _ in }
            )
        }

        await store.send(.sidebarToggleTapped) { state in
            state.isSidebarVisible = true
        }
        await store.receive(\.conversationsLoaded) { state in
            state.conversations = [conversation]
        }
        await store.receive(\.delegate.conversationsChanged)
    }

    @Test("Deleting a conversation reloads the list")
    func deleteReloadsList() async {
        let id = UUID(0)
        let store = TestStore(
            initialState: ChatHistoryFeature.State(
                conversations: [
                    ChatConversation(
                        id: id,
                        title: "Gone",
                        createdAt: Date(timeIntervalSince1970: 0),
                        updatedAt: Date(timeIntervalSince1970: 0)
                    )
                ]
            )
        ) {
            ChatHistoryFeature()
        } withDependencies: {
            $0.chatHistoryClient = ChatHistoryClient(
                listConversations: { [] },
                loadMessages: { _ in [] },
                saveConversation: { _ in },
                appendMessage: { _, _ in },
                deleteConversation: { _ in },
                setPinned: { _, _ in },
                renameConversation: { _, _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.conversationDeleted(id))
        await store.receive(\.conversationsLoaded) { state in
            state.conversations = []
        }
    }
}

@MainActor
@Suite("AppFeature Routing")
struct AppFeatureRoutingTests {
    @Test("Completed onboarding routes to home")
    func completedOnboardingRoutesHome() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature(onboardingPersistence: .preview)
        }

        await store.send(.onboarding(.completionLoaded(true))) { state in
            state.onboarding.isFinished = true
            state.route = .home
        }
    }

    @Test("Fresh onboarding keeps the onboarding route")
    func freshOnboardingStaysOnboarding() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature(onboardingPersistence: .preview)
        }

        await store.send(.onboarding(.completionLoaded(false)))
        #expect(store.state.route == .onboarding)
        #expect(store.state.onboarding.isFinished == false)
    }
}
