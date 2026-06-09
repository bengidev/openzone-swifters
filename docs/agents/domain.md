# Domain Docs

This repo is **multi-context**: a `CONTEXT-MAP.md` at the root points at one `CONTEXT.md` per context.

## Before exploring, read these

- **`CONTEXT-MAP.md`** at the repo root — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.
- **`docs/architecture/modules.md`** — read this before changing feature boundaries, shared UI/theme code, or TCA reducer/store structure.
- **`docs/architecture/swift-6-strictness.md`** — read this before changing Swift code that touches concurrency, actor isolation, Sendability, effects, persistence clients, or memory-safety settings.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The producer skill (`real-engineer-grill-with-docs`) creates them lazily when terms or decisions actually get resolved.

## File structure

Multi-context repo (presence of `CONTEXT-MAP.md` at the root):

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← system-wide decisions
├── docs/architecture/modules.md        ← feature/shared/TCA rules
├── docs/architecture/swift-6-strictness.md ← Swift 6 concurrency/memory-safety rules
├── docs/contexts/
│   ├── app/App-CONTEXT.md              ← app shell glossary
│   ├── externals/Externals-CONTEXT.md ← external integrations glossary
│   ├── shared/Shared-CONTEXT.md       ← shared UI/theme glossary
│   ├── onboarding/Onboarding-CONTEXT.md ← onboarding glossary
│   ├── home/Home-CONTEXT.md           ← home/landing glossary
│   ├── chat/Chat-CONTEXT.md           ← chat/streaming glossary
│   └── sidepanel/                     ← side panel module
│       ├── SidePanel-CONTEXT.md       ← side panel glossary
│       ├── SidePanelSession-CONTEXT.md ← session scope (ex "history chat")
│       └── SidePanelSetting-CONTEXT.md ← setting scope
└── OpenZone/
    ├── Externals/                       ← external integrations (Networking, Preference, Security)
    ├── Shared/                        ← theme + UI primitives (Theme/, UI/)
    └── Features/                       ← Onboarding, Home, Chat, SidePanel
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the relevant `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `real-engineer-grill-with-docs`).

## Flag ADR conflicts

If your plan contradicts an accepted ADR, stop and flag it rather than silently working around it.
