//
//  OpenZoneApp.swift
//  OpenZone
//
//  Created by Bambang Tri Rahmat Doni on 30/05/26.
//

import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct OpenZoneApp: App {
    @State private var appTheme: AppTheme = .system
    @State private var store: StoreOf<AppFeature>
    @Environment(\.colorScheme) private var systemColorScheme

    private let modelContainer: ModelContainer

    init() {
        let modelContainer = Self.makeModelContainer()
        self.modelContainer = modelContainer
        _store = State(
            initialValue: Store(initialState: AppFeature.State()) {
                AppFeature(onboardingPersistence: .live(modelContainer: modelContainer))
            }
        )
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
            OnboardingProgressEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var resolvedPalette: OpenZonePalette {
        .resolve(resolvedColorScheme ?? systemColorScheme)
    }

    var body: some Scene {
        WindowGroup {
            OpenZoneRootView(
                store: store,
                onThemeToggle: {
                    appTheme = appTheme.next
                }
            )
            .environment(\.palette, resolvedPalette)
            .environment(\.appTheme, appTheme)
            .preferredColorScheme(resolvedColorScheme)
            .task {
                _ = store.send(.onboarding(.onAppear))
            }
        }
        .modelContainer(modelContainer)
    }
}

/// Routes first-time users through onboarding, then shows the app shell.
private struct OpenZoneRootView: View {
    let store: StoreOf<AppFeature>
    let onThemeToggle: () -> Void

    var body: some View {
        Group {
            if store.onboarding.isFinished {
                HomeView(store: store.scope(state: \.home, action: \.home))
            } else {
                OnboardingView(
                    store: store.scope(state: \.onboarding, action: \.onboarding),
                    onThemeToggle: onThemeToggle
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.onboarding.isFinished)
    }
}
