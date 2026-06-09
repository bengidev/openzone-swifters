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
                        KeyboardAwareWelcomeContent(
                            store: store,
                            isComposerFocused: $isComposerFocused,
                            dismissKeyboard: dismissComposerKeyboard
                        )
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

            ChatErrorBannerView(store: store.scope(state: \.chat, action: \.chat))
                .animation(.easeInOut(duration: 0.2), value: store.chat.streamingStatus)

            HomeComposerView(
                store: store,
                isComposerFocused: $isComposerFocused
            )
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

            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("home-settings-button")
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
    case composer
}

private struct KeyboardAwareWelcomeContent: View {
    @Bindable var store: StoreOf<HomeFeature>
    let isComposerFocused: FocusState<Bool>.Binding
    let dismissKeyboard: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        HomeWelcomeView(store: store)
                            .frame(minHeight: welcomeMinHeight(for: proxy.size.height))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }

                        HomeComposerView(
                            store: store,
                            isComposerFocused: isComposerFocused
                        )
                        .id(HomeScrollAnchor.composer)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollDisabled(!isComposerFocused.wrappedValue)
                .scrollIndicators(isComposerFocused.wrappedValue ? .visible : .hidden)
                .onChange(of: isComposerFocused.wrappedValue) { _, isFocused in
                    guard isFocused else { return }
                    scrollComposerIntoView(with: scrollProxy)
                }
            }
        }
    }

    private func welcomeMinHeight(for availableHeight: CGFloat) -> CGFloat {
        max(availableHeight - 170, 420)
    }

    private func scrollComposerIntoView(with proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(HomeScrollAnchor.composer, anchor: .bottom)
            }
        }
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
