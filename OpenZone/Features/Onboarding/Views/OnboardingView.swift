import ComposableArchitecture
import SwiftUI

/// Main onboarding view — responsive layout with geometry-based sizing.
/// Base canvas: 375x667pt (iPhone SE). Scales proportionally for larger devices.
struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>
    let onThemeToggle: () -> Void

    @Environment(\.sharedPalette) private var palette

    init(store: StoreOf<OnboardingFeature>, onThemeToggle: @escaping () -> Void) {
        self.store = store
        self.onThemeToggle = onThemeToggle
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compactHeight = size.height < 760
            let horizontalPadding = min(max(size.width * 0.055, 20), 36)
            let visualHeight = max(
                compactHeight ? 270 : 326,
                min(size.height * (compactHeight ? 0.39 : 0.43), 390)
            )

            ZStack {
                palette.surfaceBase
                    .ignoresSafeArea()

                SharedPixelGridBackground(
                    spacing: compactHeight ? 18 : 22,
                    dotSize: 1.0,
                    opacity: palette.isDark ? 0.06 : 0.04
                )
                .ignoresSafeArea()

                SharedDiagonalHatchPattern(
                    spacing: 10,
                    opacity: palette.isDark ? 0.10 : 0.04
                )
                .ignoresSafeArea()

                VStack(spacing: compactHeight ? 12 : 18) {
                    OnboardingTopBarView(store: store, onThemeToggle: onThemeToggle)

                    OnboardingFeaturePageView(
                        page: store.currentPageData,
                        visualHeight: visualHeight,
                        store: store
                    )
                    .id(store.currentPageData.id)
                    .transition(.opacity)

                    OnboardingBottomNavigationView(store: store)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, compactHeight ? 8 : 12)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 10, 18))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .sensoryFeedback(.selection, trigger: store.currentPage)
        }
    }
}
