import ComposableArchitecture
import SwiftUI

/// Root home screen — welcome state with composer, matching the OpenSpace home layout.
struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    @Environment(\.palette) private var palette
    @FocusState private var isComposerFocused: Bool

    private let sidebarSwipeActivationWidth: CGFloat = 34
    private let sidebarSwipeThreshold: CGFloat = 64

    private var showsWelcome: Bool {
        store.chat.messages.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                palette.surfaceBase
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissComposerKeyboard()
                        }

                    if showsWelcome {
                        welcomeContent
                    } else {
                        chatThreadContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(store.sidePanel.isSidebarVisible)

                SidePanelSessionSidebarView(
                    store: store.scope(state: \.sidePanel.session, action: \.sidePanel.session)
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(sidebarSwipeGesture(in: proxy.size))
        }
        .onAppear { store.send(.onAppear) }
        .sheet(
            item: $store.scope(state: \.sidePanel.setting, action: \.sidePanel.setting)
        ) { settingStore in
            SidePanelSettingView(store: settingStore)
        }
        .sheet(isPresented: Binding(
            get: { store.isModelPopupPresented },
            set: { store.send(.modelPopupPresented($0)) }
        )) {
            HomeModelPopupView(store: store)
        }
    }

    /// Welcome hero scrolls in the area above a bottom-docked composer.
    private var welcomeContent: some View {
        WelcomeScrollContainer(
            isComposerFocused: isComposerFocused,
            dismissKeyboard: dismissComposerKeyboard
        ) { viewportHeight in
            HomeWelcomeView(
                store: store,
                viewportHeight: viewportHeight
            )
        } composer: {
            HomeComposerView(
                store: store,
                isComposerFocused: $isComposerFocused
            )
        }
    }

    private var chatThreadContent: some View {
        VStack(spacing: 0) {
            if let conversation = store.chat.conversation {
                Text(conversation.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            ChatThreadView(store: store.scope(state: \.chat, action: \.chat))
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissComposerKeyboard()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                ChatErrorBannerView(store: store.scope(state: \.chat, action: \.chat))
                    .animation(.easeInOut(duration: 0.2), value: store.chat.streamingStatus)

                HomeComposerView(
                    store: store,
                    isComposerFocused: $isComposerFocused
                )
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                store.send(.sidebarToggleTapped)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("Show sidebar")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func dismissComposerKeyboard() {
        isComposerFocused = false
    }

    private func sidebarSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                let translation = value.translation
                let mostlyHorizontal = abs(translation.width) > abs(translation.height) * 1.4
                guard mostlyHorizontal else { return }

                if store.sidePanel.isSidebarVisible {
                    guard translation.width < -sidebarSwipeThreshold else { return }
                    store.send(.sidePanel(.session(.sidebarDismissed)))
                    return
                }

                let startedAtLeadingEdge = value.startLocation.x <= sidebarSwipeActivationWidth
                guard startedAtLeadingEdge, translation.width > sidebarSwipeThreshold else { return }
                store.send(.sidebarToggleTapped)
            }
    }
}

private enum HomeScrollAnchor: Hashable {
    case welcomeTop
    case welcomeBottom
}

private struct WelcomeScrollContainer<Content: View, Composer: View>: View {
    let isComposerFocused: Bool
    let dismissKeyboard: () -> Void
    @ViewBuilder let content: (_ viewportHeight: CGFloat) -> Content
    @ViewBuilder let composer: () -> Composer

    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                Color.clear
                    .frame(height: 1)
                    .id(HomeScrollAnchor.welcomeTop)

                content(viewportHeight)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewportHeight > 0 ? viewportHeight : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }

                Color.clear
                    .frame(height: 1)
                    .id(HomeScrollAnchor.welcomeBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: WelcomeViewportHeightKey.self,
                            value: geometry.size.height
                        )
                }
            }
            .onPreferenceChange(WelcomeViewportHeightKey.self) { viewportHeight = $0 }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer()
            }
            .onChange(of: isComposerFocused) { _, isFocused in
                if isFocused {
                    scrollWelcomeAboveComposer(with: scrollProxy)
                } else {
                    scrollWelcomeToTop(with: scrollProxy)
                }
            }
        }
    }

    private func scrollWelcomeAboveComposer(with proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(HomeScrollAnchor.welcomeBottom, anchor: .bottom)
            }
        }
    }

    private func scrollWelcomeToTop(with proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(HomeScrollAnchor.welcomeTop, anchor: .top)
            }
        }
    }
}

private struct WelcomeViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        }
    )
    .environment(\.palette, .resolve(.light))
}
