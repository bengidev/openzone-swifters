import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Tests for visible failure feedback on the chat turn.
///
/// Regression: a "cannot connect" failure (missing/invalid key, HTTP 401,
/// network error at connect time) errors before any assistant row exists. The
/// error UI used to be gated on an existing assistant row, so it rendered
/// nothing — the turn failed silently. These assert the reducer surfaces the
/// failure in state (which the always-visible banner renders) and that Retry /
/// Dismiss behave.
@MainActor
@Suite("Chat Error Feedback")
struct ChatErrorFeedbackTests {

    private func makeStore(
        events: [ChatStreamingEvent],
        secondAttempt: [ChatStreamingEvent] = []
    ) -> TestStoreOf<ChatFeature> {
        // The stream factory returns the first script on the initial call and
        // the second script on retry, so a retry can succeed where send failed.
        let attempts = LockIsolated([events, secondAttempt])
        return TestStore(initialState: ChatFeature.State()) {
            ChatFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0[ProviderPreferenceClient.self] = .wrap(
                InMemoryProviderPreferenceStore(
                    preference: ProviderPreference(
                        providerID: ChatProvider.openRouter.id,
                        modelID: "meta-llama/llama-3.3-70b-instruct:free"
                    )
                )
            )
            $0[ChatAPIClient.self] = ChatAPIClient(stream: { _ in
                let script = attempts.withValue { queue -> [ChatStreamingEvent] in
                    queue.isEmpty ? [] : queue.removeFirst()
                }
                return AsyncStream { continuation in
                    for event in script { continuation.yield(event) }
                    continuation.finish()
                }
            })
        }
    }

    @Test("A connection failure surfaces a visible error in state")
    func failureSurfacesError() async {
        let store = makeStore(events: [.error(ChatStreamError(message: "Cannot connect to model."))])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hello"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamFailed)

        // The banner renders off exactly these two values.
        #expect(store.state.streamingStatus == .failed)
        #expect(store.state.streamErrorMessage == "Cannot connect to model.")
        #expect(store.state.isSending == false)
        // The user message survives the failed turn.
        #expect(store.state.messages.count == 1)
        #expect(store.state.messages.first?.role == .user)
    }

    @Test("Dismiss clears the error state")
    func dismissClearsError() async {
        let store = makeStore(events: [.error(ChatStreamError(message: "boom"))])
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hi"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamFailed)

        await store.send(.errorDismissed)
        #expect(store.state.streamErrorMessage == nil)
        #expect(store.state.streamingStatus == .idle)
    }

    @Test("Retry re-issues without appending a second user message")
    func retryReissues() async {
        let store = makeStore(
            events: [.error(ChatStreamError(message: "network down"))],
            secondAttempt: [.textDelta("Hello back"), .done]
        )
        store.exhaustivity = .off

        await store.send(.draftMessageChanged("Hi"))
        await store.send(.sendMessageTapped)
        await store.receive(\.streamFailed)
        #expect(store.state.messages.count == 1)

        await store.send(.retryTapped)
        await store.receive(\.streamCompleted)

        // Still exactly one user message; the assistant reply was added.
        let userCount = store.state.messages.filter { $0.role == .user }.count
        #expect(userCount == 1)
        #expect(store.state.streamingStatus == .done)
        #expect(store.state.streamErrorMessage == nil)
    }
}
