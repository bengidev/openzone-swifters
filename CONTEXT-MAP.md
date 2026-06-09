# Context Map

This repo uses a **multi-context** domain-doc layout (see [docs/agents/domain.md](docs/agents/domain.md)). Each context owns its own `CONTEXT.md` glossary; system-wide architectural decisions live under `docs/adr/` when recorded.

## Contexts

| Context | Code path | Context doc | ADRs |
| --- | --- | --- | --- |
| OpenZone app shell | `OpenZone/` | `docs/contexts/app/App-CONTEXT.md` | `docs/adr/` |
| External integrations | `OpenZone/Externals/` | `docs/contexts/externals/Externals-CONTEXT.md` | `docs/adr/` |
| Shared app primitives | `OpenZone/Shared/` | `docs/contexts/shared/Shared-CONTEXT.md` | `docs/adr/` |
| Onboarding feature | `OpenZone/Features/Onboarding/` | `docs/contexts/onboarding/Onboarding-CONTEXT.md` | `docs/adr/` |
| Home feature | `OpenZone/Features/Home/` | `docs/contexts/home/Home-CONTEXT.md` | `docs/adr/` |
| Chat feature | `OpenZone/Features/Chat/` | `docs/contexts/chat/Chat-CONTEXT.md` | `docs/adr/` |
| Side panel feature | `OpenZone/Features/SidePanel/` | `docs/contexts/sidepanel/SidePanel-CONTEXT.md` | `docs/adr/` |
| ↳ Side panel · session scope | `OpenZone/Features/SidePanel/` (`SidePanelSession…`) | `docs/contexts/sidepanel/SidePanelSession-CONTEXT.md` | `docs/adr/` |
| ↳ Side panel · setting scope | `OpenZone/Features/SidePanel/` (`SidePanelSetting…`) | `docs/contexts/sidepanel/SidePanelSetting-CONTEXT.md` | `docs/adr/` |

The side panel is one module that hosts two sub-scopes: **session** (saved-conversation browsing, formerly "history chat") and **setting** (app preferences). Both carry the parent `SidePanel` prefix — `SidePanelSession…` and `SidePanelSetting…`.

## Reading rules

Before working in an area:

1. Read that context's `CONTEXT.md` if it exists.
2. Read [docs/architecture/modules.md](docs/architecture/modules.md) when changing feature boundaries, shared code, or TCA structure.
3. Read [docs/architecture/swift-6-strictness.md](docs/architecture/swift-6-strictness.md) when changing concurrency, effects, or persistence clients.
4. Read `docs/adr/` for accepted decisions that affect the change.

If a listed file or directory does not exist yet, proceed without blocking. Glossaries and ADRs are added when terms or decisions are clarified ([docs/agents/domain.md](docs/agents/domain.md)).

## Agent & issue-tracker setup

Cursor agents and engineering skills read [AGENTS.md](AGENTS.md) for GitHub issue tracking ([docs/agents/issue-tracker.md](docs/agents/issue-tracker.md)) and triage labels ([docs/agents/triage-labels.md](docs/agents/triage-labels.md)).
