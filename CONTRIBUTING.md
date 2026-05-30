# Contributing to OpenZone Swifters

Thanks for your interest! Contributions of all kinds are welcome.

## How to Contribute

1. **Fork** the repo and create a branch: `git checkout -b feat/your-feature`
2. **Code** following the existing SwiftUI/SwiftData style
3. **Test** — ensure `OpenZoneTests` and `OpenZoneUITests` pass (⌘U)
4. **Commit** with clear messages (Conventional Commits encouraged: `feat:`, `fix:`, `docs:`)
5. **Push** and open a **Pull Request** describing the change and motivation

## Code Style
- Swift 6.0 — strict concurrency + `SWIFT_STRICT_MEMORY_SAFETY` enabled; resolve all data-race and memory-safety diagnostics before submitting
- SwiftUI idioms
- Prefer value types and small, composable views
- Keep AI provider code behind an abstraction (no hard-coded vendor calls in views)

## Reporting Issues
Open a GitHub Issue with:
- Steps to reproduce
- Expected vs actual behavior
- iOS version + device/simulator

## License
By contributing, you agree your work is licensed under the [MIT License](LICENSE).
