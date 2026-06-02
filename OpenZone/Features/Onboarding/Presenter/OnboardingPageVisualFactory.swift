import ComposableArchitecture
import SwiftUI

/// Factory for page-specific demo visuals — switches on page type.
enum OnboardingPageVisualFactory {
    @MainActor
    @ViewBuilder
    static func make(
        page: OnboardingPage,
        store: StoreOf<OnboardingFeature>,
        appeared: Bool
    ) -> some View {
        switch page.type {
        case .encryptedPairing:
            OnboardingEncryptedPairingVisualView(
                isConfirmed: store.pairingConfirmed,
                appeared: appeared,
                onToggle: { _ = store.send(.pairingToggleTapped) }
            )

        case .ideaStudio:
            OnboardingIdeaStudioVisualView(
                selectedPromptIndex: store.selectedPromptIndex,
                appeared: appeared,
                onPromptSelected: { _ = store.send(.promptChipTapped($0)) }
            )

        case .promptQueue:
            OnboardingPromptQueueVisualView(
                queuedPromptCount: store.queuedPromptCount,
                appeared: appeared
            )

        case .reasoningControl:
            OnboardingReasoningControlVisualView(
                reasoningLevel: Binding(
                    get: { store.reasoningLevel },
                    set: { _ = store.send(.reasoningLevelChanged($0)) }
                ),
                appeared: appeared
            )

        case .workspaceReady:
            OnboardingWorkspaceReadyVisualView(
                page: page,
                appeared: appeared
            )
        }
    }
}
