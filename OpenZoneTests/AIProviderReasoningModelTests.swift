import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Slice 5: capability-driven reasoning models.
///
/// Covers the four-tier `ExternalAIProviderReasoningModel`, its provider-effort mapping (off ->
/// no parameter), persistence through the preference store, the wire request
/// shape, and the capability gating + Settings/composer persistence wiring.
struct AIProviderReasoningModelTests {

    // MARK: - Effort mapping

    @Test("Reasoning levels map to provider effort; off maps to nil")
    func effortMapping() {
        #expect(ExternalAIProviderReasoningModel.off.effort == nil)
        #expect(ExternalAIProviderReasoningModel.low.effort == "low")
        #expect(ExternalAIProviderReasoningModel.medium.effort == "medium")
        #expect(ExternalAIProviderReasoningModel.high.effort == "high")
    }

    @Test("The exposed tiers are exactly off/low/medium/high — no fabricated tiers")
    func noFabricatedTiers() {
        #expect(ExternalAIProviderReasoningModel.allCases == [.off, .low, .medium, .high])
    }

    @Test("HomeComposerReasoningLevel is the shared ExternalAIProviderReasoningModel type")
    func composerLevelIsSharedType() {
        let level: HomeComposerReasoningLevel = .medium
        #expect(level == ExternalAIProviderReasoningModel.medium)
    }

    // MARK: - Persistence

    @Test("Preference store round-trips the reasoning level and defaults to high")
    func preferenceRoundTripsLevel() {
        let store = ExternalInMemoryAIProviderPreferenceStore()
        #expect(store.preference().reasoningModel == .high)

        store.setReasoningModel(.low)
        #expect(store.preference().reasoningModel == .low)

        store.setReasoningModel(.off)
        #expect(store.preference().reasoningModel == .off)
    }

    @Test("UserDefaults-backed store persists the reasoning level across instances")
    func userDefaultsPersistsLevel() {
        let suite = "openzone.tests.reasoning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        let writer = ExternalUserDefaultsAIProviderPreferenceStore(suiteName: suite)
        writer.setReasoningModel(.medium)

        // A fresh instance over the same suite observes the persisted value,
        // standing in for a relaunch.
        let reader = ExternalUserDefaultsAIProviderPreferenceStore(suiteName: suite)
        #expect(reader.preference().reasoningModel == .medium)
    }

    @Test("An unknown stored raw value falls back to high")
    func unknownStoredValueFallsBack() {
        let suite = "openzone.tests.reasoning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        UserDefaults(suiteName: suite)?.set("ludicrous", forKey: "openzone.provider.reasoningLevel")

        let store = ExternalUserDefaultsAIProviderPreferenceStore(suiteName: suite)
        #expect(store.preference().reasoningModel == .high)
    }
}

/// Home composer reasoning-level selection persists to the shared store and
/// seeds from it on appear.
@MainActor
@Suite("Home Reasoning Selection")
struct HomeReasoningSelectionTests {

    @Test("Selecting a reasoning level persists it to the preference store")
    func selectingLevelPersists() async {
        let backing = ExternalInMemoryAIProviderPreferenceStore()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.reasoningModelSelected(.low))

        #expect(backing.preference().reasoningModel == .low)
        #expect(store.state.reasoningModel == .low)
    }

    @Test("onAppear seeds the reasoning level from the stored preference")
    func onAppearSeedsLevel() async {
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(
                providerID: ExternalAIProviderAPI.openRouter.id,
                modelID: "deepseek/deepseek-r1:free",
                reasoningModel: .medium
            )
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.reasoningModel == .medium)
    }

    @Test("Settings sheet is seeded with the level and the model's reasoning support")
    func settingsSeededWithCapability() async {
        let known = ChatModel.curatedFallback.first { $0.supportsReasoning }!
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(
                providerID: ExternalAIProviderAPI.openRouter.id,
                modelID: known.id,
                reasoningModel: .low
            )
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.send(.sidePanel(.settingsButtonTapped))

        #expect(store.state.sidePanel.setting?.reasoningModel == .low)
        #expect(store.state.sidePanel.setting?.modelSupportsReasoning == true)
    }
}

/// The Settings reasoning control persists through the shared preference store.
@MainActor
@Suite("Settings Reasoning Control")
struct SettingsReasoningControlTests {

    @Test("Selecting a level in Settings persists it to the shared store")
    func settingsSelectionPersists() async {
        let backing = ExternalInMemoryAIProviderPreferenceStore()
        let store = TestStore(initialState: SidePanelSettingFeature.State(modelSupportsReasoning: true)) {
            SidePanelSettingFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.reasoningModelSelected(.off))

        #expect(backing.preference().reasoningModel == .off)
        #expect(store.state.reasoningModel == .off)
    }

    @Test("onAppear seeds the Settings level from the shared store")
    func settingsOnAppearSeeds() async {
        let backing = ExternalInMemoryAIProviderPreferenceStore(
            preference: ExternalAIProviderPreference(reasoningModel: .medium)
        )
        let store = TestStore(initialState: SidePanelSettingFeature.State()) {
            SidePanelSettingFeature()
        } withDependencies: {
            $0[ExternalAIProviderPreferenceClient.self] = .wrap(backing)
            $0[ExternalCredentialStoreClient.self] = ExternalCredentialStoreClient(
                secret: { _ in nil },
                save: { _, _ in },
                clear: { _ in }
            )
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.reasoningModel == .medium)
    }
}
