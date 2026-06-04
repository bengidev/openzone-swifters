# Contributing to OpenZone Swifters

Thanks for your interest! Contributions of all kinds are welcome.

This repo tracks work on [GitHub Issues](https://github.com/bengidev/openzone-swifters/issues) (`bengidev/openzone-swifters`). Domain language and architecture rules live in [CONTEXT-MAP.md](CONTEXT-MAP.md) and [docs/architecture/](docs/architecture/). Automated agents read [AGENTS.md](AGENTS.md) and [docs/agents/](docs/agents/) for issue-tracker, triage-label, and domain-doc conventions.

## How to Contribute

1. **Fork** the repo and create a branch: `git checkout -b feat/your-feature`
2. **Code** following the existing SwiftUI/SwiftData style
3. **Test** — ensure `OpenZoneTests` and `OpenZoneUITests` pass (⌘U)
4. **Commit** with clear messages (Conventional Commits encouraged: `feat:`, `fix:`, `docs:`)
5. **Push** and open a **Pull Request** describing the change and motivation

## Code Style
- Swift 6.0 with strict concurrency and `SWIFT_STRICT_MEMORY_SAFETY` enabled; resolve all data-race and memory-safety diagnostics before submitting
- Follow [Swift 6 strictness rules](docs/architecture/swift-6-strictness.md) and [module layout rules](docs/architecture/modules.md)
- Use terms from the relevant [context glossary](CONTEXT-MAP.md) when naming features, types, or issues
- Use TCA reducers/stores for feature state; do not add parallel view-model state for TCA-backed features
- SwiftUI idioms
- Prefer value types and small, composable views
- Keep AI provider code behind an abstraction (no hard-coded vendor calls in views)

## Reporting Issues

Open a [GitHub Issue](https://github.com/bengidev/openzone-swifters/issues/new) (not a file in this repo) with:

- Steps to reproduce
- Expected vs actual behavior
- iOS version + device/simulator

**Security vulnerabilities** — do not use public issues. Follow [SECURITY.md](SECURITY.md) for private reporting.

### For maintainers: triage labels

Issues use the label vocabulary in [docs/agents/triage-labels.md](docs/agents/triage-labels.md):

| Label | When to apply |
|-------|----------------|
| `needs-triage` | New issue; maintainer has not evaluated it yet |
| `needs-info` | Waiting on the reporter for clarification |
| `ready-for-agent` | Fully specified; safe for an automated agent to pick up |
| `ready-for-human` | Needs human design or implementation |
| `wontfix` | Will not be actioned |

Create these labels in the GitHub repo if they do not exist yet. CLI helpers: [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

## Domain & architecture docs

Before changing a feature area, read its `CONTEXT.md` from [CONTEXT-MAP.md](CONTEXT-MAP.md). Check `docs/adr/` for accepted decisions that affect your change. If a listed file is missing, you may still proceed — glossaries and ADRs are added when terms or decisions are settled.

## License
By contributing, you agree your work is licensed under the [MIT License](LICENSE).
