# Shared App Primitives Context

| | |
| --- | --- |
| **Context** | Shared app primitives |
| **Code** | `OpenZone/Shared/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

`OpenZone/Shared` contains cross-cutting, feature-neutral code that multiple features may depend on: external integrations (API, credentials, preferences), theme, and reusable UI primitives.

```text
OpenZone/Shared/
├── API/         # AIProviderAPI, AIProviderCredentialAPI, AIProviderSSEDecoder
├── Credential/  # CredentialStore and Keychain adapter
├── Preference/  # AIProviderPreferenceStore, AIProviderReasoningModel
├── Theme/       # palette, typography, color helpers, environment keys
└── UI/          # button styles, badges, patterns, backgrounds
```

## Language

- **Shared primitive** — reusable, feature-neutral code safe for more than one feature.
- **AI provider** — an `AIProviderAPI` descriptor (endpoint, auth scheme, default headers).
- **Provider preference** — persisted provider id, model id, and reasoning tier (`AIProviderPreference`).
- **Reasoning model** — the closed `AIProviderReasoningModel` enum mapped to `reasoning.effort` on the wire.
- **Credential store** — secure storage for the provider API secret (`CredentialStore`).
- **Theme** — app-wide color scheme preference, palette, typography, and environment keys.
- **UI primitive** — reusable visual building block such as a button style, badge, card chrome, or background pattern.

## Built-in AI providers

Shipped backends are values on `AIProviderAPI` and appear automatically in the settings provider picker via `AIProviderAPI.all`:

| ID | Display name | Base URL |
| --- | --- | --- |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` |
| `opencode` | OpenCode | `https://opencode.ai/zen/v1` |

Custom provider endpoints are out of scope — new backends ship as entries in `AIProviderAPI`.

## Architecture

- Shared code must not import or reference feature UI or TCA reducers.
- Feature domain types (e.g. `ChatModel`) belong in `Features/Chat/`.
- Feature orchestration clients (e.g. `HomeModelCatalogClient`) belong in the owning feature's folder.
- Feature-specific UI remains inside `OpenZone/Features/<FeatureName>/`.
- Same app target today — folder boundaries are the contract until promoted to a library target.

## TCA boundary

Shared exposes dependency clients (`AIProviderPreferenceClient`, `CredentialStoreClient`). Feature-scoped clients (`HomeModelCatalogClient`, `HomeModelCatalogCachePreferenceClient`) live under `Features/Home/`.

Shared UI can be used by TCA-backed feature views, but Shared should remain state-management agnostic unless a reusable component explicitly requires a binding or action closure.
