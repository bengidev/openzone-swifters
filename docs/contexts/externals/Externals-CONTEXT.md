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
├── Networking/    # ExternalAIProviderAPI, ExternalAIProviderCredentialAPI, ExternalAIProviderSSEDecoder
├── Preference/    # ExternalAIProviderPreferenceStore, ExternalAIProviderReasoningModel
└── Security/      # ExternalCredentialStore and Keychain adapter
```

## Language

- **AI provider** — an `ExternalAIProviderAPI` descriptor (endpoint, auth scheme, default headers).
- **Provider preference** — persisted provider id, model id, and reasoning tier (`ExternalAIProviderPreference`).
- **Reasoning model** — the closed `ExternalAIProviderReasoningModel` enum mapped to `reasoning.effort` on the wire.
- **Credential store** — secure storage for the provider API secret (`ExternalCredentialStore`).

## Built-in AI providers

Shipped backends are values on `ExternalAIProviderAPI` and appear automatically in the settings provider picker via `ExternalAIProviderAPI.all`:

| ID | Display name | Base URL |
| --- | --- | --- |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` |
| `opencode` | OpenCode | `https://opencode.ai/zen/v1` |
| `commandcode` | Command Code | `https://api.commandcode.ai/provider/v1` |

Command Code uses the [Provider API](https://commandcode.ai/docs/provider-api) (`POST /chat/completions`, `GET /models`) with bearer auth. Credentials are stored per provider id in the Keychain.

## Architecture

- Externals code must not import or reference feature UI or TCA reducers.
- Feature domain types (e.g. `ChatModel`) belong in `Features/Chat/Models/`.
- Feature orchestration clients (e.g. `HomeModelCatalogClient`) belong in the owning feature's folder.
- Same app target today — folder boundaries are the contract until promoted to a library target.

## TCA boundary

Externals exposes dependency clients (`ExternalAIProviderPreferenceClient`, `ExternalCredentialStoreClient`). Feature-scoped clients (`HomeModelCatalogClient`, `HomeModelCatalogCachePreferenceClient`) live under `Features/Home/Core/`.
