# Side Panel — Setting Scope

| | |
| --- | --- |
| **Context** | Side panel → setting scope |
| **Code** | `OpenZone/Features/SidePanel/` (`SidePanelSetting…` symbols) |
| **Parent** | [SidePanel context](./SidePanel-CONTEXT.md) |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The setting scope is the app-preferences surface inside the side panel. It was previously a separate settings feature; it now lives inside the side panel alongside the session scope.

## Language

- **Setting** — an adjustable app-wide preference (theme, provider, credential entry points).
- **Setting surface** — the rendered preferences view inside the side panel (`SidePanelSettingView`).

## Architecture

- State lives in the setting scope's reducer (`SidePanelSettingFeature`); intents are its actions.
- Preference reads/writes go through `Externals` clients (`AIProviderPreferenceClient`, `CredentialStoreClient`) and the shared theme preference — never direct persistence from views.
- The setting view (`SidePanelSettingView`) renders the setting surface from the store.

## Provider selection

- The settings sheet exposes a **menu picker** (dropdown) over `AIProviderAPI.all` — not a segmented tab control — so additional built-in providers scale without crowding the layout.
- Selection writes `providerID` through `AIProviderPreferenceClient`; credentials are keyed per provider in the Keychain.
- **Custom providers are out of scope:** users cannot add their own base URLs or provider definitions. New backends ship as entries in `AIProviderAPI`.

## Naming convention

All setting-scope symbols and files use the `SidePanelSetting` prefix, then a role suffix per the [file-naming rules](../../architecture/modules.md#file-naming) — e.g. `SidePanelSettingView` (view), `SidePanelSettingFeature` (reducer).

## Migration note

This scope supersedes the former standalone settings feature. Existing `SettingsView` / `SettingsFeature` map to `SidePanelSetting*` equivalents under this scope.

## Boundaries

- Owns app preferences presentation only. Secure credential storage and provider preference persistence stay in `OpenZone/Externals`.
- Reuse theme and UI primitives from `OpenZone/Shared`.
