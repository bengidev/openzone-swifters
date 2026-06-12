# Shared Context

| | |
| --- | --- |
| **Context** | Cross-feature reusable UI |
| **Code** | `OpenZone/Shared/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |
| **Dependency** | None |

The Shared context contains UI primitives, theme definitions, and utilities that are used by multiple features. Types in this boundary use the `Shared` prefix to indicate they are cross-feature reusable components.

```text
OpenZone/Shared/
├── Theme/
│   ├── SharedAppTheme.swift
│   ├── SharedOpenZonePalette.swift
│   ├── SharedOpenZoneTypography.swift
│   └── Color+Hex.swift
└── UI/
    ├── SharedBadge.swift
    ├── SharedButtonStyles.swift
    ├── SharedCardChrome.swift
    ├── SharedDiagonalHatchPattern.swift
    ├── SharedPixelGridBackground.swift
    ├── SharedSignalGlitchModifier.swift
    └── SharedThemeToggleButton.swift
```

## Dependencies

None. Shared is a leaf dependency — it must not import any feature code.

## Type Prefix Convention

All public types use the `Shared` prefix:
- `SharedAppTheme` — theme mode and system integration
- `SharedOpenZonePalette` — color palette and SwiftUI environment key
- `SharedOpenZoneTypography` — font definitions
- `SharedBadge`, `SharedCardChrome`, `SharedButtonStyles`, etc.

## Key Responsibilities

- **Theme management** — `SharedAppTheme` handles light/dark/system themes
- **Color palette** — `SharedOpenZonePalette` defines OpenZone brand colors
- **Typography** — `SharedOpenZoneTypography` provides font scale
- **UI components** — Reusable SwiftUI modifiers and views (`SharedBadge`, `SharedCardChrome`, etc.)

## Usage Pattern

Features import Shared types directly:

```swift
struct HomeView: View {
    @Environment(\\.sharedAppTheme) var theme
    @Environment(\\.sharedPalette) var palette
    
    var body: some View {
        SharedCardChrome {
            SharedBadge("Status")
        }
        .background(palette.surface)
    }
}
```

## Constraints

- **No feature imports** — Shared must never import `Home`, `Chat`, `Onboarding`, or `SidePanel`
- **No business logic** — Only UI primitives and theme definitions
- **No state management** — No `@Model`, reducers, or persistence code

## Recent Changes

- Added `Shared` prefix to all public types to clarify cross-feature reusability
- Removed `public` modifiers (internal by default per architecture rules)
- Reorganized into `Theme/` and `UI/` subdirectories
