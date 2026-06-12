import ComposableArchitecture
import SwiftUI

/// Page content container — context chip, headline, body, demo visual, highlights.
struct OnboardingFeaturePageView: View {
    let page: OnboardingPage
    let visualHeight: CGFloat
    let store: StoreOf<OnboardingFeature>

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        if page.type == .workspaceReady {
            OnboardingPageVisualFactory.make(page: page, store: store, appeared: appeared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: page.id) {
                    await runEntrance()
                }
        } else {
            VStack(alignment: .leading, spacing: 13) {
                // Context chip + state code
                HStack(spacing: 10) {
                    SharedBadge(title: page.eyebrow, systemImage: badgeSymbol, isActive: true)
                    Spacer(minLength: 8)
                    Text(page.indexLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(-0.24)
                        .foregroundStyle(palette.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.accentPrimary.opacity(palette.isDark ? 0.12 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(palette.accentPrimary.opacity(0.28), lineWidth: 1)
                        )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

                // Primary message — headline
                Text(page.headline)
                    .font(.system(size: titleSize, weight: .regular))
                    .tracking(-1.2)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                // Supporting copy
                Text(page.body)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                // Demonstration panel
                SharedCardChrome(cornerRadius: 6) {
                    ZStack {
                        palette.surfacePaper

                        SharedPixelGridBackground(
                            spacing: 15,
                            dotSize: 1.0,
                            opacity: palette.isDark ? 0.06 : 0.04
                        )

                        SharedDiagonalHatchPattern(
                            spacing: 10,
                            opacity: palette.isDark ? 0.10 : 0.04
                        )

                        if page.type == .promptQueue {
                            VStack(spacing: 0) {
                                terminalHeader
                                    .padding(.horizontal, 14)
                                    .padding(.top, 14)
                                    .padding(.bottom, 8)

                                GeometryReader { bodyProxy in
                                    ScrollViewReader { scrollProxy in
                                        ScrollView(.vertical, showsIndicators: false) {
                                            OnboardingPageVisualFactory.make(page: page, store: store, appeared: appeared)
                                                .frame(minHeight: bodyProxy.size.height, alignment: .center)
                                        }
                                        .scrollIndicators(.hidden)
                                        .contentMargins(.vertical, 0, for: .scrollContent)
                                        .scrollBounceBehavior(.basedOnSize)
                                        .padding(.horizontal, 14)
                                        .onChange(of: store.queuedPromptCount) { _, newValue in
                                            if newValue > 0 {
                                                withAnimation(.easeOut(duration: 0.32)) {
                                                    scrollProxy.scrollTo("queueLast", anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                                }

                                Button {
                                    _ = store.send(.addQueuedPromptButtonTapped)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                        Text(store.queuedPromptCount >= OnboardingQueueItem.samples.count ? "RESET QUEUE" : "ADD FOLLOW-UP")
                                        Spacer()
                                        Text("⌘↩")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .tracking(-0.24)
                                            .foregroundStyle(palette.textTertiary)
                                    }
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .tracking(-0.24)
                                    .foregroundStyle(palette.accentPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(palette.accentPrimary.opacity(0.11))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(palette.accentPrimary.opacity(0.28), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add follow-up prompt")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                highlightFooter
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 14)
                            }
                        } else {
                            VStack(spacing: 12) {
                                terminalHeader
                                OnboardingPageVisualFactory.make(page: page, store: store, appeared: appeared)
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                highlightFooter
                            }
                            .padding(14)
                        }
                    }
                    .frame(height: visualHeight)
                }
                .signalGlitch(progress: appeared ? 1 : 0, intensity: page.shaderIntensity)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.985)
                .offset(y: appeared ? 0 : 14)
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.82), value: appeared)
            .task(id: page.id) {
                await runEntrance()
            }
        }
    }

    private var titleSize: CGFloat {
        page.headline.count > 58 ? 27 : 30
    }

    private var badgeSymbol: String {
        switch page.type {
        case .encryptedPairing: "lock.shield"
        case .ideaStudio: "sparkles"
        case .promptQueue: "text.line.first.and.arrowtriangle.forward"
        case .reasoningControl: "slider.horizontal.3"
        case .workspaceReady: "sparkle"
        }
    }

    @MainActor
    private func runEntrance() async {
        appeared = false
        guard !reduceMotion else {
            appeared = true
            return
        }
        try? await Task.sleep(nanoseconds: 70_000_000)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            appeared = true
        }
    }

    private var terminalHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle().fill(palette.accentPrimary).frame(width: 7, height: 7)
                Circle().fill(palette.textTertiary.opacity(0.42)).frame(width: 7, height: 7)
                Circle().fill(palette.textTertiary.opacity(0.24)).frame(width: 7, height: 7)
            }

            Text(page.metric)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(-0.24)
                .foregroundStyle(palette.textSecondary)

            Spacer()

            Text("AGENTS / PROMPTS / MODELS / REVIEW")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .tracking(-0.24)
                .foregroundStyle(palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(palette.lineSoft, lineWidth: 1)
        )
    }

    private var highlightFooter: some View {
        HStack(spacing: 8) {
            ForEach(Array(page.highlights.enumerated()), id: \.element.id) { index, highlight in
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == 0 ? palette.accentPrimary.opacity(0.12) : palette.surfaceSubtle.opacity(0.4))
                            .frame(width: 28, height: 28)
                        Image(systemName: highlight.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index == 0 ? palette.accentPrimary : palette.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(highlight.title.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(-0.24)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(highlight.detail)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(palette.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.surfacePaper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(palette.lineSoft, lineWidth: 1)
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.42, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appeared)
            }
        }
    }
}
