# Shared App Primitives Context

| | |
| --- | --- |
| **Context** | Shared app primitives |
| **Code** | `OpenZone/Shared/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

`OpenZone/Shared` contains app-wide theme and UI primitives that are safe for multiple features to reuse.

```text
OpenZone/Shared/
├── Theme/    # Shared palette, typography, color helpers, environment keys
└── UI/       # Shared button styles, badges, patterns, backgrounds
```

External integrations live in `OpenZone/Externals/` — see [Externals context](../externals/Externals-CONTEXT.md).

## Language

- **Shared primitive** — reusable, feature-neutral UI or theme code whose file and primary type use the `Shared…` prefix.
- **Theme** — app-wide color scheme preference, palette, typography, and environment keys; concrete shared theme types use the `Shared…` prefix. Product-branded names are not exceptions: `OpenZonePalette`/`OpenZoneTypography`/`AppTheme` become `SharedOpenZonePalette`/`SharedOpenZoneTypography`/`SharedAppTheme`. Extension-only helpers over external types are wrapped in shared helper types, e.g. `Color+Hex` becomes `SharedColorHex`, called through a static factory such as `SharedColorHex.color("0B0B0B")` rather than a `Color` extension initializer. Shared-owned SwiftUI environment properties use shared-prefixed names: `\.sharedPalette` and `\.sharedAppTheme`. Custom TCA `DependencyValues` properties follow the same boundary-prefix rule in their owning boundary. Shared SwiftUI extension helpers may remain extension methods, but method names also use `shared…`, e.g. `.sharedMonoTracking()` and `.sharedSignalGlitch(...)`.
- **UI primitive** — reusable visual building block such as a button style, badge, card chrome, or background pattern; concrete shared UI types use the `Shared…` prefix.

## Architecture

- Shared code must not import or reference feature code.
- Shared code must not contain feature-specific copy, workflow state, or TCA reducers.
- Shared source uses default `internal` access while it remains inside the app target; do not keep `public` solely for a possible future package.
- Feature-specific UI remains inside `OpenZone/Features/<FeatureName>/`.

## TCA boundary

Shared UI can be used by TCA-backed feature views, but Shared should remain state-management agnostic unless a reusable component explicitly requires a binding or action closure.
