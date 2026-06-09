# Settings Context

| | |
| --- | --- |
| **Context** | Settings feature |
| **Code** | `OpenZone/Features/Settings/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

The settings feature owns the API key settings sheet: entering, saving, and clearing the provider secret, plus reasoning effort when the selected model supports it.

## Language

- **Settings sheet** — modal surface (`SettingsView`) for credential and reasoning configuration.
- **Draft API key** — in-progress value in the secure field; cleared after a successful save so the secret does not linger in feature state.
- **Stored key** — whether a provider secret exists in the Keychain; drives save affordances and the home send gate.
- **Reasoning model** — persisted `AIProviderReasoningModel` tier, shared with the composer via `AIProviderPreferenceClient`.

## Architecture

- State lives in `SettingsFeature.State`; user intents are `SettingsFeature.Action`.
- The reducer uses `CredentialStoreClient` and `AIProviderPreferenceClient` from `OpenZone/Externals/`; it never holds the secret beyond the in-flight draft.
- `SettingsFeature` is composed at **AppFeature** level via `@Presents` and `.ifLet`, not inside `HomeFeature`.
- `AppFeature` seeds presentation state (stored-key flag, reasoning tier, model capability) and refreshes home send eligibility when the sheet saves, clears, or dismisses.
- `SettingsView` receives `StoreOf<SettingsFeature>` and sends actions through the store.

## Boundaries

- Keep credential entry, Keychain writes, and reasoning preference editing inside this context.
- Do not duplicate preference or credential clients; use Externals dependency clients only.
- Workspace and composer gating react to outcomes (key stored or cleared) via the app shell; settings does not import Home reducers.
- Do not add separate `@Observable` view-model classes; TCA is the source of truth for this feature.
