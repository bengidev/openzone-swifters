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
    ) -> Self? {
        let heroHeight = orbHeight + orbBottomPadding + heroTextBlockHeight
        guard heroHeight <= viewportHeight else { return nil }

        let spacing = max(minEdgeSpacing, (viewportHeight - heroHeight) / 2)

        return Self(
            topSpacerMinLength: spacing,
            bottomSpacerMinLength: spacing,
            orbHeight: orbHeight,
            orbBottomPadding: orbBottomPadding
        )
    }
}

struct HomeWelcomeView: View {
    let store: StoreOf<HomeFeature>
    let viewportHeight: CGFloat

    @Environment(\.sharedPalette) private var palette

    private var layout: HomeWelcomeLayoutMetrics {
        HomeWelcomeLayoutMetrics.resolve(viewportHeight: viewportHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: layout.topSpacerMinLength)

            HomeParticleOrbView()
                .frame(maxWidth: .infinity)
                .frame(height: layout.orbHeight)
                .padding(.bottom, layout.orbBottomPadding)

            Text("Hi! How can I help you?")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text("Chats are end-to-end encrypted.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 12)

            Text("Your data is safe.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 4)

            Spacer(minLength: layout.bottomSpacerMinLength)
        }
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.2), value: viewportHeight)
    }
}
