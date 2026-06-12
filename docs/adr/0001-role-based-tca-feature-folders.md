# 0001. Role-based TCA feature folders

Date: 2026-06-12

## Status

Accepted

## Context

OpenZone is a single app target today, but feature folders are treated as module boundaries that may later become internal Swift packages or Xcode framework targets. The previous architecture rule kept feature folders flat and relied entirely on scope-prefixed file names.

The planned refactor reorganizes each `OpenZone/Features/<FeatureName>/` folder to match a TCA-oriented role taxonomy. This is hard to reverse once many files and references move, and a future reader would otherwise wonder why the repo left the documented flat-folder rule.

## Decision

Place app-shell code under `OpenZone/App/`: `OpenZoneApp.swift` at the app-shell folder root, `AppFeature.swift` under `OpenZone/App/Core/`, and app-shell SwiftUI helper views under `OpenZone/App/Views/` (e.g. `AppRootView.swift`). Keep two conventional names: `OpenZoneApp` is the SwiftUI `@main` app entry point and `AppFeature` is the TCA root reducer, not a feature workflow under `OpenZone/Features/`. Other app-shell helper types use the `App…` prefix.

Use these default subfolders inside each feature folder:

- `Core/` — reducers, reducer-scoped effects, feature-scoped dependency clients, and state orchestration code.
- `Models/` — feature-owned value/domain types.
- `Views/` — SwiftUI views and feature-owned visual components.
- `Utilities/` — feature-scoped helpers, factories, formatters, persistence entities, and other support code that is not state orchestration.

Additional role folders may be added only when a feature has a concrete need that the default taxonomy cannot name cleanly.

Keep `OpenZone/Externals/` and `OpenZone/Shared/` on their existing technical subfolders instead of forcing `Core`/`Models`/`Views`/`Utilities`; those folders are cross-cutting boundaries, not TCA feature workflows.

For SidePanel specifically, group sub-scope files under `Session/` or `Setting/` inside the relevant role folder because it intentionally hosts two named sub-scopes. Keep `SidePanelFeature.swift` at `SidePanel/Core/` as the host reducer.

Mirror feature tests under `OpenZoneTests/Features/<FeatureName>/`. Add role folders inside a feature's test folder only when the test volume justifies them. Cross-cutting tests use folders matching source boundaries (`App`, `Externals`, `Shared`). Test file names and primary test types follow the same boundary-prefix rule as production code.

Perform the migration as a clean cutover across the repo: move sources, split helper types, rename files/types, and update every call site and test in the same change. Do not leave compatibility aliases, shims, or mixed old/new folder conventions behind.

Keep strict boundary-prefixed file and top-level type names after the move. Split every top-level helper type into its own file directly under the relevant role folder rather than keeping multiple private types in a large source file or hiding them under `Internal/`. SwiftUI presentation helper types such as `ViewModifier`, `ButtonStyle`, `ToggleStyle`, view-local `PreferenceKey`, and visual layout helpers live in `Views/`. Use default `internal` access for app-target source and remove existing `public` declarations unless a promoted framework/package boundary actually requires them. Split helper types use default `internal` access when another file needs them; ownership is conveyed by prefix and folder until module boundaries are promoted. SwiftUI `#Preview` blocks stay with the primary view file. Feature-owned files take the feature prefix, including technical clients (e.g. `ChatOpenAICompatibleStreamingClient`). Implementation/helper names in every boundary put domain before technology after the boundary prefix, e.g. `HomeModelCatalogCachePreferenceUserDefaultsStore`, `ChatOpenAICompatibleStreamingClient`, `ExternalAIProviderPreferenceUserDefaultsStore`, and `ExternalCredentialKeychainStore`. Persistence entities include their persistence subdomain when one exists, e.g. `ChatHistoryConversationEntity`, `ChatHistoryMessageEntity`, and `ChatHistoryMessageKind`. Side-panel sub-scopes keep `SidePanelSession…` and `SidePanelSetting…`. Cross-cutting boundaries also take explicit prefixes: `OpenZone/Externals/` uses `External…`, and `OpenZone/Shared/` uses `Shared…`, including product-branded shared theme types such as `SharedOpenZonePalette`, `SharedOpenZoneTypography`, and `SharedAppTheme`. Externals implementation types put domain before technology after the boundary prefix, e.g. `ExternalAIProviderPreferenceUserDefaultsStore` and `ExternalCredentialKeychainStore`. Extension-only helpers over external types are replaced with boundary-prefixed helper types, e.g. `SharedColorHex`, and exposed through static factories such as `SharedColorHex.color("0B0B0B")` rather than kept as unprefixed extension files or `Color` extension initializers. Shared-owned SwiftUI environment values use shared-prefixed property names (`\.sharedPalette`, `\.sharedAppTheme`) instead of unprefixed names. Shared SwiftUI extension helpers keep extension-method ergonomics but use shared-prefixed method names such as `.sharedMonoTracking()` and `.sharedSignalGlitch(...)`. Custom TCA `DependencyValues` properties also use boundary prefixes, e.g. `\.externalCredentialStore`, `\.externalProviderPreference`, `\.homeModelCatalog`, and `\.chatHistoryClient`. Private functions and properties do not need a prefix. Do not keep feature-local typealiases solely as compatibility shims for renamed cross-boundary types.

## Consequences

- Feature folders become deeper but easier to scan by TCA role.
- File count rises because helper types move into dedicated files.
- App-target source becomes consistently `internal` by default; some split helper types also become `internal` because Swift `private` is file-scoped.
- File moves should not require Xcode project edits because the project uses file-system-synchronized root groups.
- Scope prefixes remain necessary because folders alone do not provide Swift namespacing inside the app target.
- The architecture guide supersedes the previous flat-feature-folder rule.
