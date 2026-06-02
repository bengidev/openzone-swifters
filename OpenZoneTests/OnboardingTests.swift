import ComposableArchitecture
import SwiftUI
import Testing
@testable import OpenZone

@MainActor
@Suite("Onboarding Domain Tests")
struct OnboardingTests {

    @Test("OnboardingPage.all has 5 pages in correct order")
    func pageCount() {
        #expect(OnboardingPage.all.count == 5)
        #expect(OnboardingPage.all[0].type == .encryptedPairing)
        #expect(OnboardingPage.all[1].type == .ideaStudio)
        #expect(OnboardingPage.all[2].type == .promptQueue)
        #expect(OnboardingPage.all[3].type == .reasoningControl)
        #expect(OnboardingPage.all[4].type == .workspaceReady)
    }

    @Test("OnboardingPage has unique IDs")
    func pageIDs() {
        let ids = OnboardingPage.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("OnboardingPromptOption has 3 samples")
    func promptOptions() {
        #expect(OnboardingPromptOption.samples.count == 3)
        #expect(OnboardingPromptOption.samples[0].label == "ASK")
        #expect(OnboardingPromptOption.samples[1].label == "WRITE")
        #expect(OnboardingPromptOption.samples[2].label == "EXPLORE")
    }

    @Test("OnboardingQueueItem has 4 samples with correct statuses")
    func queueItems() {
        #expect(OnboardingQueueItem.samples.count == 4)
        #expect(OnboardingQueueItem.samples[0].status == .running)
        #expect(OnboardingQueueItem.samples[1].status == .next)
        #expect(OnboardingQueueItem.samples[2].status == .queued)
        #expect(OnboardingQueueItem.samples[3].status == .ready)
    }

    @Test("OnboardingPageType has all cases")
    func pageTypes() {
        #expect(OnboardingPageType.allCases.count == 5)
    }
}

@MainActor
@Suite("OnboardingFeature Tests")
struct OnboardingFeatureTests {

    @Test("Initial state is page 0, not finished")
    func initialState() {
        let state = OnboardingFeature.State()
        #expect(state.currentPage == 0)
        #expect(state.isFinished == false)
        #expect(state.totalPages == 5)
        #expect(state.isLastPage == false)
    }

    @Test("nextButtonTapped advances page")
    func nextButtonTapped() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.nextButtonTapped) {
            $0.currentPage = 1
        }
    }

    @Test("previousButtonTapped goes back")
    func previousButtonTapped() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: 1)) {
            OnboardingFeature()
        }

        await store.send(.previousButtonTapped) {
            $0.currentPage = 0
        }
    }

    @Test("previousButtonTapped clamps at 0")
    func previousClamp() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.previousButtonTapped)
    }

    @Test("pageSelected jumps to index")
    func pageSelected() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.pageSelected(3)) {
            $0.currentPage = 3
        }
    }

    @Test("skipButtonTapped jumps to last page")
    func skipButtonTapped() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.skipButtonTapped) {
            $0.currentPage = $0.totalPages - 1
        }
    }

    @Test("promptChipTapped updates selection")
    func promptChip() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.promptChipTapped(2)) {
            $0.selectedPromptIndex = 2
        }
    }

    @Test("addQueuedPromptButtonTapped increments count")
    func addQueue() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.addQueuedPromptButtonTapped) {
            $0.queuedPromptCount = 3
        }
    }

    @Test("reasoningLevelChanged clamps value")
    func reasoningClamp() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.reasoningLevelChanged(1.5)) {
            $0.reasoningLevel = 1.0
        }
        await store.send(.reasoningLevelChanged(-0.5)) {
            $0.reasoningLevel = 0.0
        }
    }

    @Test("pairingToggleTapped toggles state")
    func pairingToggle() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.pairingToggleTapped) {
            $0.pairingConfirmed = false
        }
    }
}

@MainActor
@Suite("Theme Tests")
struct ThemeTests {

    @Test("OpenZonePalette light mode has correct base color")
    func lightPalette() {
        let palette = OpenZonePalette.resolve(.light)
        #expect(palette.isDark == false)
    }

    @Test("OpenZonePalette dark mode has correct base color")
    func darkPalette() {
        let palette = OpenZonePalette.resolve(.dark)
        #expect(palette.isDark == true)
    }

    @Test("AppTheme cycles correctly")
    func themeCycle() {
        #expect(AppTheme.system.next == .light)
        #expect(AppTheme.light.next == .dark)
        #expect(AppTheme.dark.next == .system)
    }
}
