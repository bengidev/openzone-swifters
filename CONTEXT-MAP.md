# Context Map

This repo uses a multi-context domain-doc layout. Each context owns its own `CONTEXT.md` glossary and optional ADR decisions.

## Contexts

| Context | Code path | Context doc | ADRs |
| --- | --- | --- | --- |
| OpenZone app shell | `OpenZone/` | `docs/contexts/app/CONTEXT.md` | `docs/adr/` |
| Shared app primitives | `OpenZone/Shared/` | `docs/contexts/shared/CONTEXT.md` | `docs/adr/` |
| Onboarding feature | `OpenZone/Features/Onboarding/` | `docs/contexts/onboarding/CONTEXT.md` | `docs/adr/` |

## Reading rules for agents

Before working in an area, read the relevant context's `CONTEXT.md` if it exists. Then read root `docs/adr/` for decisions affecting the change.

If a listed file or directory does not exist yet, proceed silently. Domain docs are created lazily when terms or decisions are clarified.

## Architecture notes

See `docs/architecture/modules.md` for the current feature/shared layout, TCA state-management rules, and the future path to internal Swift Package or Xcode framework targets. See `docs/architecture/swift-6-strictness.md` before changing concurrency, actor isolation, Sendability, or memory-safety settings.
