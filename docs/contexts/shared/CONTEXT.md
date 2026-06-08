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
├── Theme/    # palette, typography, color helpers, environment keys
└── UI/       # button styles, badges, patterns, backgrounds
```

External integrations live in `OpenZone/Externals/` — see [Externals context](../externals/CONTEXT.md).

## Language

- **Shared primitive** — reusable, feature-neutral UI or theme code.
- **Theme** — app-wide color scheme preference, palette, typography, and environment keys.
- **UI primitive** — reusable visual building block such as a button style, badge, card chrome, or background pattern.

## Architecture

- Shared code must not import or reference feature code.
- Shared code must not contain feature-specific copy, workflow state, or TCA reducers.
- Feature-specific UI remains inside `OpenZone/Features/<FeatureName>/Presenter`.

## TCA boundary

Shared UI can be used by TCA-backed feature views, but Shared should remain state-management agnostic unless a reusable component explicitly requires a binding or action closure.
