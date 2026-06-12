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
├── Preference/    # ExternalAIProviderPreferenceStore, ExternalAIProviderReasoningModel, domain-first concrete stores
└── Security/      # ExternalCredentialStore and domain-first Keychain adapter
```

## Language

- **AI provider** — an `ExternalAIProviderAPI` descriptor (endpoint, auth scheme, default headers).
- **Provider preference** — persisted provider id, model id, and reasoning tier (`ExternalAIProviderPreference`).
- **Reasoning model** — the closed `ExternalAIProviderReasoningModel` enum mapped to `reasoning.effort` on the wire.
- **Credential store** — secure storage for the provider API secret (`ExternalCredentialStore`); concrete adapters use domain-first names such as `ExternalCredentialKeychainStore` and `ExternalCredentialKeychainError`.

## Built-in AI providers

Shipped backends are values on `ExternalAIProviderAPI` and appear automatically in the settings provider picker via `ExternalAIProviderAPI.all`:

| ID | Display name | Base URL |
| --- | --- | --- |
| `openrouter` | OpenRouter | `https://openrouter.ai/api/v1` |
| `opencode` | OpenCode | `https://opencode.ai/zen/v1` |
| `commandcode` | Command Code | `https://api.commandcode.ai/provider/v1` |

Command Code uses the Provider API (`POST /chat/completions`, `GET /models`) with bearer auth. Credentials are stored per provider id in the Keychain. Concrete Externals implementation names put domain before technology, e.g. `ExternalAIProviderPreferenceUserDefaultsStore` rather than `ExternalUserDefaultsAIProviderPreferenceStore`.

## Architecture

- Externals code must not import or reference feature UI or TCA reducers.
- Feature domain types (e.g. `ChatModel`) belong in `Features/Chat/`.
- Feature orchestration clients (e.g. `HomeModelCatalogClient`) belong in the owning feature's folder.
- Same app target today — folder boundaries are the contract until promoted to a library target.
- Externals source uses default `internal` access while it remains inside the app target; introduce `public` only when a separate target needs the API.

## TCA boundary

Externals exposes dependency clients (`ExternalAIProviderPreferenceClient`, `ExternalCredentialStoreClient`). Their custom TCA dependency keys use external-prefixed properties such as `\.externalProviderPreference` and `\.externalCredentialStore`. Feature-scoped clients (`HomeModelCatalogClient`, `HomeModelCatalogCachePreferenceClient`) live under `Features/Home/`.
