import ComposableArchitecture
import Foundation
import Testing

@testable import OpenZone

/// Slice 5: capability-driven reasoning levels.
///
/// Covers the four-tier reasoning level, its provider-effort mapping (off ->
/// no parameter), persistence through the preference store, the wire request
/// shape, and the capability gating + Settings/composer persistence wiring.
struct ReasoningLevelTests {

    // MARK: - Effort mapping

    @Test("Reasoning levels map to provider effort; off maps to nil")
    func effortMapping() {
        #expect(ReasoningLevel.off.effort == nil)
        #expect(ReasoningLevel.low.effort == "low")
        #expect(ReasoningLevel.medium.effort == "medium")
        #expect(ReasoningLevel.high.effort == "high")
    }

    @Test("The exposed tiers are exactly off/low/medium/high — no fabricated tiers")
    func noFabricatedTiers() {
        #expect(ReasoningLevel.allCases == [.off, .low, .medium, .high])
    }

    @Test("HomeComposerReasoningLevel is the shared ReasoningLevel type")
    func composerLevelIsSharedType() {
        let level: HomeComposerReasoningLevel = .medium
        #expect(level == ReasoningLevel.medium)
    }

    // MARK: - Persistence

    @Test("Preference store round-trips the reasoning level and defaults to high")
    func preferenceRoundTripsLevel() {
        let store = InMemoryProviderPreferenceStore()
        #expect(store.preference().reasoningLevel == .high)

        store.setReasoningLevel(.low)
        #expect(store.preference().reasoningLevel == .low)

        store.setReasoningLevel(.off)
        #expect(store.preference().reasoningLevel == .off)
    }

    @Test("UserDefaults-backed store persists the reasoning level across instances")
    func userDefaultsPersistsLevel() {
        let suite = "openzone.tests.reasoning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        let writer = UserDefaultsProviderPreferenceStore(suiteName: suite)
        writer.setReasoningLevel(.medium)

        // A fresh instance over the same suite observes the persisted value,
        // standing in for a relaunch.
        let reader = UserDefaultsProviderPreferenceStore(suiteName: suite)
        #expect(reader.preference().reasoningLevel == .medium)
    }

    @Test("An unknown stored raw value falls back to high")
    func unknownStoredValueFallsBack() {
        let suite = "openzone.tests.reasoning.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        UserDefaults(suiteName: suite)?.set("ludicrous", forKey: "openzone.provider.reasoningLevel")

        let store = UserDefaultsProviderPreferenceStore(suiteName: suite)
        #expect(store.preference().reasoningLevel == .high)
    }
}

/// Home composer reasoning-level selection persists to the shared store and
/// seeds from it on appear.
@MainActor
@Suite("Home Reasoning Selection")
struct HomeReasoningSelectionTests {

    @Test("Selecting a reasoning level persists it to the preference store")
    func selectingLevelPersists() async {
        let backing = InMemoryProviderPreferenceStore()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
        }
        store.exhaustivity = .off

        await store.send(.reasoningLevelSelected(.low))

        #expect(backing.preference().reasoningLevel == .low)
        #expect(store.state.reasoningLevel == .low)
    }

    @Test("onAppear seeds the reasoning level from the stored preference")
    func onAppearSeedsLevel() async {
        let backing = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(
                providerID: ChatProvider.openRouter.id,
                modelID: "deepseek/deepseek-r1:free",
                reasoningLevel: .medium
            )
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.reasoningLevel == .medium)
    }

    @Test("Settings sheet is seeded with the level and the model's reasoning support")
    func settingsSeededWithCapability() async {
        let known = ChatModel.curatedFallback.first { $0.supportsReasoning }!
        let backing = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(
                providerID: ChatProvider.openRouter.id,
                modelID: known.id,
                reasoningLevel: .low
            )
        )
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0[ProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.send(.settingsButtonTapped)

        #expect(store.state.settings?.reasoningLevel == .low)
        #expect(store.state.settings?.modelSupportsReasoning == true)
    }
}

/// The Settings reasoning control persists through the shared preference store.
@MainActor
@Suite("Settings Reasoning Control")
struct SettingsReasoningControlTests {

    @Test("Selecting a level in Settings persists it to the shared store")
    func settingsSelectionPersists() async {
        let backing = InMemoryProviderPreferenceStore()
        let store = TestStore(initialState: SettingsFeature.State(modelSupportsReasoning: true)) {
            SettingsFeature()
        } withDependencies: {
            $0[ProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
        }
        store.exhaustivity = .off

        await store.send(.reasoningLevelSelected(.off))

        #expect(backing.preference().reasoningLevel == .off)
        #expect(store.state.reasoningLevel == .off)
    }

    @Test("onAppear seeds the Settings level from the shared store")
    func settingsOnAppearSeeds() async {
        let backing = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(reasoningLevel: .medium)
        )
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0[ProviderPreferenceClient.self] = .wrap(backing)
            $0[CredentialStoreClient.self] = .wrap(InMemoryCredentialStore())
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.reasoningLevel == .medium)
    }
}
