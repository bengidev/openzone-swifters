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
    @State private var sharedAppTheme: SharedAppTheme = .system
    @State private var store: StoreOf<AppFeature>
    @Environment(\.colorScheme) private var systemColorScheme

    private let modelContainer: ModelContainer

    init() {
        let modelContainer = Self.makeModelContainer()
        self.modelContainer = modelContainer
        _store = State(
            initialValue: Store(initialState: AppFeature.State()) {
                AppFeature(
                    onboardingPersistence: .live(modelContainer: modelContainer),
                    chatHistory: .live(modelContainer: modelContainer)
                )
            }
        )
    }

    private static func makeModelContainer() -> ModelContainer {
        // Schema is extended additively: the two chat-history entities are
        // added and the dead template stub (`Item`) is dropped. SwiftData
        // performs a lightweight automatic migration of the existing on-disk
        // store on first launch — adding the new entities and ignoring the
        // removed one — which is exercised by the migration test against a
        // pre-populated store.
        let schema = Schema([
            OnboardingProgressEntity.self,
            ChatHistoryConversationEntity.self,
            ChatHistoryMessageEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch sharedAppTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var resolvedPalette: SharedOpenZonePalette {
        .resolve(resolvedColorScheme ?? systemColorScheme)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                store: store,
                onThemeToggle: {
                    sharedAppTheme = sharedAppTheme.next
                }
            )
            .environment(\.sharedPalette, resolvedPalette)
            .environment(\.sharedAppTheme, sharedAppTheme)
            .preferredColorScheme(resolvedColorScheme)
            .task {
                _ = store.send(.onboarding(.onAppear))
            }
        }
        .modelContainer(modelContainer)
    }
}

/// Routes first-time users through onboarding, then shows the app shell.
private struct AppRootView: View {
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
