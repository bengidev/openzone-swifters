# Context Map

This repo uses a multi-context domain-doc layout. Each context owns its own `CONTEXT.md` glossary and optional `docs/adr/` decisions.

## Contexts

| Context | Path | Context doc | ADRs |
| --- | --- | --- | --- |
| OpenZone app | `OpenZone/` | `OpenZone/CONTEXT.md` | `OpenZone/docs/adr/` |
| OnboardingKit package | `Packages/OnboardingKit/` | `Packages/OnboardingKit/CONTEXT.md` | `Packages/OnboardingKit/docs/adr/` |

## Reading rules for agents

Before working in an area, read the relevant context's `CONTEXT.md` if it exists. Then read root `docs/adr/` and the context-specific `docs/adr/` for decisions affecting the change.

If a listed file or directory does not exist yet, proceed silently. Domain docs are created lazily when terms or decisions are clarified.
