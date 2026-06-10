import ComposableArchitecture
import SwiftUI

struct HomeComposerView: View {
    @Bindable var store: StoreOf<HomeFeature>
    let isComposerFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 8) {
            HomeComposerPromptPanel(
                store: store,
                isComposerFocused: isComposerFocused
            )
            HomeComposerContextRail(
                store: store,
                dismissKeyboard: dismissKeyboard
            )
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

private struct HomeComposerPromptPanel: View {
    @Bindable var store: StoreOf<HomeFeature>
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.palette) private var palette
    @State private var sendFeedbackTrigger = false

    private var canSend: Bool {
        !store.chat.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.chat.isSending
            && store.hasAPIKey
            && store.hasSelectedModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.hasAPIKey {
                MissingAPIKeyHint { store.send(.sidePanel(.settingsButtonTapped)) }
            }

            TextField(
                "Ask anything... @files, $skills, /commands",
                text: Binding(
                    get: { store.chat.draftMessage },
                    set: { store.send(.chat(.draftMessageChanged($0))) }
                ),
                axis: .vertical
            )
            .frame(minHeight: 50)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(palette.textPrimary)
            .lineLimit(1...5)
            .textInputAutocapitalization(.sentences)
            .focused(isComposerFocused)

            HStack(spacing: 6) {
                HomeComposerIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Add attachment",
                    action: {
                        dismissKeyboard()
                        store.send(.attachmentTapped)
                    }
                )

                Spacer(minLength: 4)

                HomeComposerIconButton(
                    systemImage: "mic",
                    accessibilityLabel: "Start voice input",
                    action: {
                        dismissKeyboard()
                        store.send(.microphoneTapped)
                    }
                )

                HomeComposerSendButton(canSend: canSend, action: send)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .homeComposerGlass(cornerRadius: 28, shadowOpacity: 0.16)
        .sensoryFeedback(.success, trigger: sendFeedbackTrigger)
    }

    private func send() {
        guard canSend else { return }
        dismissKeyboard()
        sendFeedbackTrigger.toggle()
        store.send(.chat(.sendMessageTapped))
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

private struct HomeComposerContextRail: View {
    @Bindable var store: StoreOf<HomeFeature>
    let dismissKeyboard: () -> Void

    @State private var isContextUsagePresented = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                HomeComposerModelButton(
                    title: store.selectedModelOption?.title ?? "Select model",
                    dismissKeyboard: dismissKeyboard
                ) {
                    dismissKeyboard()
                    store.send(.modelPopupPresented(true))
                }
                .accessibilityLabel("Model, \(store.selectedModelOption?.title ?? "none selected")")

                if store.selectedModelOption?.supportsReasoning == true {
                    HomeComposerMenuChip(
                        title: store.reasoningModel.title,
                        systemImage: "circle.hexagongrid",
                        minWidth: 92,
                        dismissKeyboard: dismissKeyboard
                    ) {
                        Section("Reasoning") {
                            ForEach(HomeComposerReasoningLevel.allCases) { level in
                                Button {
                                    dismissKeyboard()
                                    store.send(.reasoningModelSelected(level))
                                } label: {
                                    Label(
                                        level.title,
                                        systemImage: store.reasoningModel == level ? "checkmark" : "circle"
                                    )
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Reasoning, \(store.reasoningModel.title)")
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let speedModes = store.selectedModelOption?.availableSpeedModes,
                   !speedModes.isEmpty {
                    HomeComposerMenuChip(
                        title: store.speedMode.title,
                        systemImage: store.speedMode.systemImage,
                        displaysTitle: false,
                        displaysChevron: false,
                        isSignal: store.speedMode == .fast,
                        minWidth: 38,
                        dismissKeyboard: dismissKeyboard
                    ) {
                        Section("Speed") {
                            ForEach(speedModes) { speedMode in
                                Button {
                                    dismissKeyboard()
                                    store.send(.speedModeSelected(speedMode))
                                } label: {
                                    Label(speedMode.title, systemImage: speedMode.systemImage)
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Speed, \(store.speedMode.title)")
                }

                HomeComposerContextUsageButton(
                    usage: store.contextUsage,
                    isPresented: $isContextUsagePresented,
                    dismissKeyboard: dismissKeyboard
                )
            }
        }
        .padding(.horizontal, 2)
        .overlay(alignment: .bottomTrailing) {
            if isContextUsagePresented {
                HomeComposerContextUsagePopover(usage: store.contextUsage)
                    .offset(x: -2, y: -46)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isContextUsagePresented)
    }
}

private struct HomeComposerMenuChip<MenuItems: View>: View {
    let title: String
    let systemImage: String?
    let displaysTitle: Bool
    let displaysChevron: Bool
    let isSignal: Bool
    let minWidth: CGFloat
    let dismissKeyboard: () -> Void
    let menuItems: MenuItems

    @Environment(\.palette) private var palette

    init(
        title: String,
        systemImage: String? = nil,
        displaysTitle: Bool = true,
        displaysChevron: Bool = true,
        isSignal: Bool = false,
        minWidth: CGFloat = 0,
        dismissKeyboard: @escaping () -> Void = {},
        @ViewBuilder menuItems: () -> MenuItems
    ) {
        self.title = title
        self.systemImage = systemImage
        self.displaysTitle = displaysTitle
        self.displaysChevron = displaysChevron
        self.isSignal = isSignal
        self.minWidth = minWidth
        self.dismissKeyboard = dismissKeyboard
        self.menuItems = menuItems()
    }

    var body: some View {
        Menu {
            menuItems
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }

                if displaysTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if displaysChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSignal ? palette.accentPrimary : palette.textSecondary)
            .frame(minWidth: minWidth)
            .frame(height: 30)
            .padding(.horizontal, displaysTitle ? 10 : 8)
            .homeComposerGlass(cornerRadius: 16, shadowOpacity: 0.06)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
    }
}

private struct HomeComposerContextUsageButton: View {
    let usage: HomeComposerContextUsage
    @Binding var isPresented: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        Button {
            dismissKeyboard()
            isPresented.toggle()
        } label: {
            HomeComposerContextUsageIndicator(usage: usage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context usage")
        .accessibilityValue("\(usage.usedPercent)% used, \(usage.remainingPercent)% left")
    }
}

private struct HomeComposerContextUsageIndicator: View {
    let usage: HomeComposerContextUsage

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.42 : 0.72))

            Circle()
                .stroke(palette.accentPrimary.opacity(palette.isDark ? 0.14 : 0.12), lineWidth: 3)
                .frame(width: 23, height: 23)

            Circle()
                .trim(from: 0, to: usage.usedFraction)
                .stroke(
                    palette.accentPrimary.opacity(palette.isDark ? 0.92 : 0.82),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 23, height: 23)

            Text("\(usage.usedPercent)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.accentPrimary)
        }
        .frame(width: 38, height: 38)
        .background(.ultraThinMaterial, in: Circle())
        .overlay {
            Circle()
                .stroke(palette.accentPrimary.opacity(palette.isDark ? 0.18 : 0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct HomeComposerContextUsagePopover: View {
    let usage: HomeComposerContextUsage

    @Environment(\.palette) private var palette

    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Context window")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                Spacer(minLength: 10)

                Text("\(usage.usedPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.accentSoft.opacity(palette.isDark ? 0.35 : 1), in: Capsule())
            }

            ProgressView(value: usage.usedFraction)
                .tint(palette.accentPrimary)
                .scaleEffect(x: 1, y: 0.72, anchor: .center)

            HStack(spacing: 10) {
                Text("\(usage.usedPercent)% used")
                    .foregroundStyle(palette.textPrimary)

                Spacer(minLength: 8)

                Text("\(usage.remainingPercent)% left")
                    .foregroundStyle(palette.textTertiary)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))

            Text("\(usage.usedTokensLabel) / \(usage.tokenLimitLabel) tokens")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: 202)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.isDark ? palette.surfacePaper.opacity(0.78) : palette.surfaceRaised.opacity(0.82))
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.65), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

private struct MissingAPIKeyHint: View {
    let openSettings: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: openSettings) {
            HStack(spacing: 8) {
                Image(systemName: "key.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)

                Text("Add an API key in Settings to start sending")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.5 : 0.8))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an API key in Settings to start sending")
        .accessibilityIdentifier("composer-missing-key-hint")
    }
}

private struct HomeComposerIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HomeComposerSendButton: View {
    let canSend: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(canSend ? palette.controlStrongText : palette.textTertiary)
                .frame(width: 34, height: 34)
                .background(canSend ? palette.controlStrong : palette.surfaceSubtle.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send message")
    }
}

private struct HomeComposerGlassChrome: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.isDark ? palette.surfacePaper.opacity(0.7) : palette.surfaceRaised.opacity(0.72))
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.35 : 0.55), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private extension View {
    func homeComposerGlass(cornerRadius: CGFloat, shadowOpacity: Double) -> some View {
        modifier(HomeComposerGlassChrome(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

/// A plain button that visually matches `HomeComposerMenuChip` but fires a
/// tap action instead of presenting a menu — used for the model chip which
/// opens the full-screen model popup.
private struct HomeComposerModelButton: View {
    let title: String
    let dismissKeyboard: () -> Void
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.textSecondary)
            .frame(minWidth: 104)
            .frame(height: 30)
            .padding(.horizontal, 10)
            .homeComposerGlass(cornerRadius: 16, shadowOpacity: 0.06)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
    }
}
