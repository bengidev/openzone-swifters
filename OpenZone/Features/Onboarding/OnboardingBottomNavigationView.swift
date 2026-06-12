import ComposableArchitecture
import SwiftUI

/// Bottom navigation — pagination dots + back/continue action row.
struct OnboardingBottomNavigationView: View {
    let store: StoreOf<OnboardingFeature>

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicators — small neutral dots, blue pill for active
            HStack(spacing: 8) {
                ForEach(0..<store.totalPages, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            _ = store.send(.pageSelected(index))
                        }
                    } label: {
                        Capsule(style: .continuous)
                            .fill(index == store.currentPage ? palette.accentPrimary : palette.lineSoft)
                            .frame(width: index == store.currentPage ? 28 : 6, height: 6)
                            .animation(.spring(response: 0.34, dampingFraction: 0.76), value: store.currentPage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to onboarding page \(index + 1)")
                }
            }

            // Action row — one primary, optional secondary
            HStack(spacing: 10) {
                if store.currentPage > 0 {
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            _ = store.send(.previousButtonTapped)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("BACK")
                        }
                    }
                    .buttonStyle(SharedSecondaryButtonStyle(palette: palette))
                    .accessibilityLabel("Previous onboarding page")
                }

                Button {
                    if store.isLastPage {
                        _ = store.send(.finishButtonTapped)
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            _ = store.send(.nextButtonTapped)
                        }
                    }
                } label: {
                    HStack(spacing: 9) {
                        Text(store.isLastPage ? "ENTER OPENZONE" : "CONTINUE")
                        Image(systemName: store.isLastPage ? "arrow.up.right" : "arrow.right")
                    }
                }
                .buttonStyle(SharedPrimaryButtonStyle(palette: palette))
                .accessibilityLabel(store.isLastPage ? "Enter OpenZone" : "Continue onboarding")
            }
        }
    }
}
