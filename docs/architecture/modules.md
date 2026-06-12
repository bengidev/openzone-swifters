# Module Layout

Part of this repo's multi-context documentation. See [CONTEXT-MAP.md](../../CONTEXT-MAP.md) for per-feature glossaries and [docs/agents/domain.md](../agents/domain.md) for how agents consume domain docs.

OpenZone uses feature-oriented folders inside the app target today. The folders are intentionally shaped like modules so they can be promoted to internal Swift Package or Xcode framework targets later without rewriting the feature boundaries.

State management is implemented with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture). New product workflows should follow the same reducer/store pattern.

Swift code must also follow the repo's Swift 6 strictness rules in `docs/architecture/swift-6-strictness.md`.

## Module map

The app is a single root that composes feature modules as siblings, plus a cross-cutting shared layer. `SidePanel` is one module that hosts two sub-scopes — `Session` (saved-conversation browsing, formerly "history chat") and `Setting` (app preferences):

```text
App
├── Shared        # API/Theme/Credential + UI primitives (cross-cutting)
├── Onboarding
├── Home
├── Chat
└── SidePanel
    ├── Session    # SidePanelSession… (ex "history chat")
    └── Setting    # SidePanelSetting…
```

## Target layout

```text
OpenZone/
├── App/
│   ├── OpenZoneApp.swift
│   ├── Core/
│   │   └── AppFeature.swift
│   └── Views/
│       └── AppRootView.swift
├── Features/
│   ├── Onboarding/
│   │   ├── Core/             # OnboardingFeature, persistence client
│   │   ├── Models/           # pages, prompt options, feature highlights
│   │   ├── Views/            # SwiftUI views and visual components
│   │   └── Utilities/        # feature-scoped factories/helpers/entities
│   ├── Home/
│   │   ├── Core/             # HomeFeature, model catalog clients
│   │   ├── Models/           # composer/model-selection value types
│   │   ├── Views/            # SwiftUI views
│   │   └── Utilities/        # feature-scoped helpers when needed
│   ├── Chat/
│   │   ├── Core/             # ChatFeature, API/history/stream clients
│   │   ├── Models/           # messages, conversations, requests, stream events
│   │   ├── Views/            # SwiftUI thread/message/error views
│   │   └── Utilities/        # feature-scoped helpers/entities when needed
│   └── SidePanel/            # hosts Session + Setting sub-scopes
│       ├── Core/
│       │   ├── SidePanelFeature.swift
│       │   ├── Session/
│       │   └── Setting/
│       ├── Models/
│       │   └── Session/
│       ├── Views/
│       │   ├── Session/
│       │   └── Setting/
│       └── Utilities/
├── Externals/                # External integrations; keep technical folders
│   ├── Networking/
│   ├── Preference/
│   └── Security/
└── Shared/                   # Shared primitives; keep Theme/UI
    ├── Theme/
    └── UI/
```

> Feature folders use role-based TCA subfolders: `Core`, `Models`, `Views`, and `Utilities` as the default taxonomy. Add another role folder only when a feature has a concrete need that the standard taxonomy cannot name cleanly.
>
> Scope prefixes: every symbol/file carries its module scope. Feature files use their feature prefix; `Externals` files use `External…`; `Shared` files use `Shared…`. The side panel's sub-scopes extend the parent prefix — `SidePanelSession…` for the session (ex "history chat") scope and `SidePanelSetting…` for the setting scope — and may be grouped under `Session/` or `Setting/` inside the role folders.

## State management rules

- The app shell lives under `OpenZone/App/`; `AppFeature` is root composition, not a feature workflow under `OpenZone/Features/`.
- The app root owns a `StoreOf<AppFeature>`.
- Each feature owns a TCA reducer named `<FeatureName>Feature`.
- Feature views receive `StoreOf<<FeatureName>Feature>` and send actions through `store.send(...)`.
- Do not add separate `@Observable` view-model classes for TCA-backed features. State belongs in `@ObservableState`; mutations belong in reducer actions.
- Side effects (persistence, networking, system adapters) run from reducer effects and use explicit dependency clients.
- Tests should use `TestStore` for reducer behavior, plus normal view/unit tests where useful.

## Test layout

Feature tests mirror the feature boundary under `OpenZoneTests/Features/<FeatureName>/`. Start with one folder per feature; add `Core/`, `Models/`, `Views/`, or `Utilities/` inside a feature's test folder only when the test volume makes the extra role folder useful.

Cross-cutting tests use folders that match the source boundary, e.g. `OpenZoneTests/Externals/`, `OpenZoneTests/Shared/`, or `OpenZoneTests/App/`.

Test file names and primary test types follow the same boundary-prefix rule as production code. For example, tests for `ExternalCredentialStore` live under `OpenZoneTests/Externals/` and use `ExternalCredentialStoreTests`.

## Migration sequencing

Apply layout and prefix migrations as a clean cutover across the repo: move sources, split helper types, rename files/types, and update every call site and test in the same change. Do not leave compatibility aliases, shims, or mixed old/new folder conventions behind.

## File naming

One top-level type per file; the file name matches that primary type. Split every additional top-level helper type — including helper structs, enums, classes, protocols, and styles — into its own boundary-prefixed file. Put split helper files directly in the relevant role folder (`Views/`, `Models/`, `Core/`, or `Utilities/`), not in an `Internal/` subfolder. SwiftUI presentation helper types such as `ViewModifier`, `ButtonStyle`, `ToggleStyle`, view-local `PreferenceKey`, and visual layout helpers live in `Views/`. Private functions and properties may stay with the type they support. SwiftUI `#Preview` blocks may stay in the primary view file because they are not top-level types.

The suffix conveys the type's **role**, not the module — the module is already conveyed by the scope prefix.

- `…Feature` — a TCA reducer (`@Reducer struct …Feature`). There is normally exactly one per module. The `Feature` suffix is reserved for reducers; do not append it to non-reducer files.
- `…View` — SwiftUI view.
- `…Client` — dependency client or adapter surface.
- `…Store` — concrete persistence store.
- Domain/value names use the domain noun, still with the boundary prefix.

So within a module only the single reducer file carries `Feature`; every other file is named by its role. This is why most files have no `Feature` suffix — they aren't reducers.

> Note: a literal "Feature" inside a domain name (e.g. `OnboardingFeatureHighlight`, `OnboardingFeaturePageView` — "feature highlight" as a product concept) is part of the noun, not the reducer suffix, and does not imply a reducer.
>
> Every file and every top-level type uses its boundary prefix, including helper types that were previously `private` inside large files. Feature-owned files use the feature scope prefix; `OpenZone/Externals/` files use `External…`; `OpenZone/Shared/` files use `Shared…`. App-shell exceptions are `OpenZoneApp` for the SwiftUI `@main` entry point and `AppFeature` for the TCA root reducer; other app-shell helper types should use `App…`. Use default `internal` access for app-target source; remove existing `public` declarations unless a promoted framework/package boundary actually requires them. Split helper types use default `internal` access when another file needs them; ownership is conveyed by prefix and folder because this is still one app target. Do not keep technical-name exceptions inside feature folders; e.g. a Chat-owned OpenAI-compatible streaming client uses the `Chat…` prefix. Private functions and properties do not need a prefix. Do not keep feature-local typealias files solely to preserve old names after a boundary rename; migrate call sites to the canonical type.

## Ownership rules

### `OpenZone/App/`

The app shell owns entry-point wiring, root store creation, app-wide dependency setup, and global routing. `OpenZoneApp.swift` stays at the app-shell folder root because SwiftUI app entry points conventionally carry the product name. `AppFeature.swift` lives under `OpenZone/App/Core/` because it is the TCA root reducer. App-shell SwiftUI helper views live under `OpenZone/App/Views/` and use the `App…View` prefix, e.g. `AppRootView.swift`.

### `OpenZone/Features/<FeatureName>/`

A feature owns one product workflow. Its folder uses role-based TCA subfolders:

- `Core/` — reducers (`<FeatureName>Feature`), reducer-scoped effects, feature-scoped dependency clients, and other orchestration code that mutates or feeds feature state.
- `Models/` — value/domain types owned by the feature.
- `Views/` — SwiftUI views and feature-owned visual components.
- `Utilities/` — feature-scoped helpers, factories, formatters, persistence entities, and other support code that is not itself state orchestration. Persistence entities include their persistence subdomain when one exists, e.g. `ChatHistoryConversationEntity`, `ChatHistoryMessageEntity`, and `ChatHistoryMessageKind`.

Use scope-prefixed file names (e.g. `HomeFeature`, `HomeComposerView`, `ChatHistoryClient`) so ownership remains clear after files move into role folders. Implementation/helper names in every boundary put domain before technology after the boundary prefix, e.g. `HomeModelCatalogCachePreferenceUserDefaultsStore`, `ChatOpenAICompatibleStreamingClient`, `ExternalAIProviderPreferenceUserDefaultsStore`, and `ExternalCredentialKeychainStore`.

Feature code may depend on `OpenZone/Externals`, `OpenZone/Shared`, Swift standard libraries, Apple frameworks, TCA, and its own feature folders. Feature code must not depend on another feature directly unless a clear integration boundary is introduced.

#### `OpenZone/Features/SidePanel/`

The side panel is one feature module that hosts two sub-scopes, each scope-prefixed:

- **Session** (`SidePanelSession…`) — saved-conversation browsing, formerly "history chat". Lists and groups persisted conversations and hands off to Chat to open a thread. Consumes Chat's history persistence (`ChatHistoryClient`); does not own the live stream.
- **Setting** (`SidePanelSetting…`) — app preferences. Reads/writes through `Externals` clients and the shared theme preference.

Because the side panel has named sub-scopes, place sub-scope files under `Session/` or `Setting/` inside the relevant role folder: e.g. `SidePanel/Core/Session/SidePanelSessionFeature.swift`, `SidePanel/Models/Session/SidePanelSessionSection.swift`, and `SidePanel/Views/Setting/SidePanelSettingView.swift`. Keep the host reducer at `SidePanel/Core/SidePanelFeature.swift`.

### `OpenZone/Externals/`

Externals contains feature-neutral adapters for systems outside the app:

- `Networking/` — `ExternalAIProviderAPI`, `ExternalAIProviderCredentialAPI`, `ExternalAIProviderSSEDecoder`.
- `Preference/` — `ExternalAIProviderPreference`, `ExternalAIProviderReasoningModel`, `ExternalAIProviderPreferenceStore`, `ExternalAIProviderPreferenceClient`, and concrete stores named domain-first such as `ExternalAIProviderPreferenceUserDefaultsStore` or `ExternalAIProviderPreferenceInMemoryStore`.
- `Security/` — `ExternalCredentialStore`, `ExternalCredentialStoreClient`, and concrete Keychain types named domain-first such as `ExternalCredentialKeychainStore` and `ExternalCredentialKeychainError`.

Externals keeps its technical subfolders (`Networking`, `Preference`, `Security`) rather than adopting the feature role taxonomy. It is a cross-cutting adapter boundary, not a TCA feature workflow.

Externals must not reference feature UI or reducers. Chat domain types (e.g. `ChatModel`) belong in `Features/Chat/`. Home-scoped orchestration (e.g. `HomeModelCatalogClient`) belongs in the owning feature's folder. Chat streaming and chat history persistence stay in `Features/Chat/` because they combine provider wire behavior with chat domain types. The side panel's session scope consumes that persistence; it does not duplicate it.

### `OpenZone/Shared/`

Shared contains app-wide UI primitives that are safe for more than one feature to reuse:

- `Theme/` — `Shared…` palette, theme preference, typography, color helpers, and SwiftUI environment keys. Product-branded shared theme types are not exceptions: `OpenZonePalette`/`OpenZoneTypography`/`AppTheme` migrate to `SharedOpenZonePalette`/`SharedOpenZoneTypography`/`SharedAppTheme`. Extension-only helpers over external types are wrapped in boundary-prefixed helper types instead of kept as unprefixed extension files; e.g. `Color+Hex.swift` becomes `SharedColorHex.swift`, exposed through a static factory such as `SharedColorHex.color("0B0B0B")` rather than a `Color` extension initializer. Shared-owned SwiftUI environment properties also use the shared prefix: `\.palette` and `\.appTheme` migrate to `\.sharedPalette` and `\.sharedAppTheme`. Shared SwiftUI extension helpers remain extension methods for view-modifier ergonomics, but their method names use the shared prefix, e.g. `.monoTracking()` and `.signalGlitch(...)` migrate to `.sharedMonoTracking()` and `.sharedSignalGlitch(...)`. Custom TCA `DependencyValues` properties also use boundary prefixes, e.g. `\.externalCredentialStore`, `\.externalProviderPreference`, `\.homeModelCatalog`, and `\.chatHistoryClient`.
- `UI/` — `Shared…` reusable visual primitives, patterns, and button styles.

Shared keeps its technical subfolders (`Theme`, `UI`) rather than adopting the feature role taxonomy. It is a cross-cutting primitive boundary, not a TCA feature workflow.

Shared code must not import or reference feature code. If a component contains onboarding-specific copy, state, or workflow behavior, keep it in `Features/<FeatureName>` instead of `Shared`.

## Why not marker enum files?

Do not add empty `enum SharedModule {}` or `enum FeatureModules {}` files just to document folders. They add symbols without runtime value. Keep developer guidance in `docs/architecture/` and keep source folders focused on executable app code.

## Future internal-library path

If module boundaries need compiler enforcement, promote these folders in this order. Introduce `public` APIs only at the promotion step where another target needs them:

1. Promote `OpenZone/Externals/` to an internal Xcode framework or Swift Package.
2. Promote `OpenZone/Shared/` (Theme + UI) to an internal `OpenZoneShared` library.
3. Promote `OpenZone/Features/<FeatureName>/` to feature targets.
4. Wire dependencies: features → `Externals`, `OpenZoneShared`, TCA.
5. Make the app target depend on the feature libraries.

Keep those libraries private to this repo unless a feature becomes reusable across multiple apps. Remote packages add versioning, CI, and cross-repo coordination overhead, so they should be introduced only when reuse justifies it.
