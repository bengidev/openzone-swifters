# Externals Context

| | |
| --- | --- |
| **Context** | External integrations |
| **Code** | `OpenZone/Externals/` |
| **Map** | [CONTEXT-MAP.md](../../../CONTEXT-MAP.md) |
| **Layout rules** | [docs/architecture/modules.md](../../architecture/modules.md) |

`OpenZone/Externals/` holds feature-neutral adapters for systems outside the app: networking primitives, persisted preferences, and secure credential storage. Chat domain types and feature-specific clients live in `Features/`, not here.

```text
OpenZone/Externals/
├── Networking/    # AIProviderAPI, AIProviderCredentialAPI, AIProviderSSEDecoder
├── Preference/    # AIProviderPreferenceStore, AIProviderReasoningModel
└── Security/      # CredentialStore and Keychain adapter
```

## Language

- **AI provider** — an `AIProviderAPI` descriptor (endpoint, auth scheme, default headers).
- **Provider preference** — persisted provider id, model id, and reasoning tier (`AIProviderPreference`).
- **Reasoning model** — the closed `AIProviderReasoningModel` enum mapped to `reasoning.effort` on the wire.
- **Credential store** — secure storage for the provider API secret (`CredentialStore`).

## Built-in AI providers

Shipped backends are values on `AIProviderAPI` and appear automatically in the settings provider picker via `AIProviderAPI.all`:

| ID | Display name | Base URL |
| --- | --- | --- |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` |
| `opencode` | OpenCode | `https://opencode.ai/zen/v1` |
| `commandcode` | Command Code | `https://api.commandcode.ai/provider/v1` |

Command Code uses the [Provider API](https://commandcode.ai/docs/provider-api) (`POST /chat/completions`, `GET /models`) with bearer auth. Credentials are stored per provider id in the Keychain.

## Architecture

- Externals code must not import or reference feature UI or TCA reducers.
- Feature domain types (e.g. `ChatModel`) belong in `Features/Chat/`.
- Feature orchestration clients (e.g. `HomeModelCatalogClient`) belong in the owning feature's folder.
- Same app target today — folder boundaries are the contract until promoted to a library target.

## TCA boundary

Externals exposes dependency clients (`AIProviderPreferenceClient`, `CredentialStoreClient`). Feature-scoped clients (`HomeModelCatalogClient`, `HomeModelCatalogCachePreferenceClient`) live under `Features/Home/`.
