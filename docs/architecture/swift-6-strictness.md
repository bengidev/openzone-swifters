# Swift 6 Strictness

OpenZone is compiled in Swift 6 mode with strict concurrency and strict memory-safety diagnostics enabled. Treat these diagnostics as design feedback, not as noise to suppress.

## Build settings

The app and test targets should keep these settings enabled:

```text
SWIFT_VERSION = 6.0
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_STRICT_CONCURRENCY = complete
SWIFT_STRICT_MEMORY_SAFETY = YES
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
```

The app target also keeps script sandboxing off only where Xcode currently requires it for the target configuration. Project-level script sandboxing remains enabled.

## Coding rules

- Prefer value types for domain models. Make cross-actor value types `Sendable` when they can cross task or actor boundaries.
- Keep UI-facing feature state on the main actor. TCA reducers and SwiftUI views run from the app's main-actor defaults.
- Do not capture non-`Sendable` values in `@Sendable` async closures. Extract immutable values before launching effects.
- Keep SwiftData access behind infrastructure clients. Do not let views directly perform persistence side effects.
- Keep long-running or fallible work in explicit TCA effects, not in view bodies.
- Avoid global mutable state. If shared state is needed, model it as a dependency/client with controlled isolation.
- Do not silence concurrency diagnostics with unchecked annotations unless an ADR explains why the boundary is safe.

## TCA-specific rules

- Feature state lives in `@ObservableState` structs.
- Feature mutations happen only through reducer actions.
- Side effects return `Effect` values from reducers.
- Views send actions via `StoreOf<Feature>` and should not create parallel view models for the same state.
- Tests use `TestStore` to assert state transitions and effects.

## Review checklist

Before merging Swift code, verify:

1. `xcodebuild -scheme OpenZone -project OpenZone.xcodeproj -destination 'generic/platform=iOS Simulator' build` succeeds.
2. `xcodebuild test -scheme OpenZone -project OpenZone.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17'` succeeds when a simulator is available.
3. No new strict-concurrency or memory-safety warnings are introduced.
4. Any `nonisolated`, `@unchecked Sendable`, or actor-boundary workaround is documented in code and, if architectural, in an ADR.
