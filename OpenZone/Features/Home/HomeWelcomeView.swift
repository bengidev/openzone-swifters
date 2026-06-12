[OpenZone/Features/Home/HomeWelcomeView.swift#A88D]
import ComposableArchitecture
import SwiftUI

/// Vertically centers the welcome hero inside the scroll viewport above the composer.
struct HomeWelcomeLayoutMetrics {
    let topSpacerMinLength: CGFloat
    let bottomSpacerMinLength: CGFloat
    let orbHeight: CGFloat
    let orbBottomPadding: CGFloat

    private static let heroTextBlockHeight: CGFloat = 66
    private static let minEdgeSpacing: CGFloat = 16
    private static let standardOrbHeight: CGFloat = 260
    private static let standardOrbPadding: CGFloat = 28
    private static let compactOrbHeight: CGFloat = 200
    private static let compactOrbPadding: CGFloat = 20

    static func resolve(viewportHeight: CGFloat) -> Self {
        guard viewportHeight > 0 else {
            return Self(
                topSpacerMinLength: 72,
                bottomSpacerMinLength: 72,
                orbHeight: standardOrbHeight,
                orbBottomPadding: standardOrbPadding
            )
        }

        if let standard = centeredMetrics(
            viewportHeight: viewportHeight,
            orbHeight: standardOrbHeight,
            orbBottomPadding: standardOrbPadding
        ) {
            return standard
        }

        let compactHeroHeight = compactOrbHeight + compactOrbPadding + heroTextBlockHeight
        let spacing = max(
            minEdgeSpacing,
            (viewportHeight - compactHeroHeight) / 2
        )

        return Self(
            topSpacerMinLength: spacing,
            bottomSpacerMinLength: spacing,
            orbHeight: compactOrbHeight,
            orbBottomPadding: compactOrbPadding
        )
    }

    private static func centeredMetrics(
        viewportHeight: CGFloat,
        orbHeight: CGFloat,
        orbBottomPadding: CGFloat
54-65:    ) -> Self? { .. }
}

struct HomeWelcomeView: View {
    let store: StoreOf<HomeFeature>
    let viewportHeight: CGFloat = 0

    @Environment(\.palette) private var palette

    private var layout: HomeWelcomeLayoutMetrics {
        HomeWelcomeLayoutMetrics.resolve(viewportHeight: viewportHeight)
    }

78-107:    var body: some View { .. }
}

[38 lines elided; re-read needed ranges with /Users/beng/Documents/iOS Projects/OpenZone/OpenZone/Features/Home/HomeWelcomeView.swift:54-65,78-107]