# OpenZone Swifters

> Native mobile AI assistant for iOS — bring AI models to your pocket to help get work done.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.6%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

OpenZone Swifters is a **native iOS AI assistant** built with SwiftUI, SwiftData, and The Composable Architecture (TCA). It integrates mobile-first UX with AI models so users can complete real tasks — drafting, summarizing, planning, Q&A, and more — directly from their device.

## ✨ Features

- 🤖 **AI model integration** — connect on-device or remote AI models to power assistant workflows
- 📱 **Native SwiftUI** — fluid, platform-native interface
- 💾 **SwiftData persistence** — local-first storage for chats, history, and context
- 🔒 **Privacy-aware** — designed to keep user data on-device where possible
- ⚡ **Task-oriented** — focused on helping users finish work, not just chat
- 🛡️ **Swift 6 strict memory safety** — built with strict concurrency and memory-safety checks enabled

## 🧱 Tech Stack

| Layer        | Technology            |
|--------------|-----------------------|
| Language     | Swift 6.0             |
| UI           | SwiftUI               |
| Persistence  | SwiftData             |
| State         | The Composable Architecture 1.25.5 |
| Min Target   | iOS 17.6+             |
| App Category | Productivity          |
| Concurrency  | Swift 6 strict concurrency + strict memory safety |

## 🚀 Getting Started

### Prerequisites
- Xcode 16+
- iOS 17.6+ device or simulator

### Build & Run
```bash
git clone https://github.com/bengidev/openzone-swifters.git
cd openzone-swifters
open OpenZone.xcodeproj
```
Select a simulator/device and press **⌘R**.

## 📂 Project Structure

```
OpenZone/
├── OpenZoneApp.swift          # App entry, AppRoute routing, SwiftData ModelContainer
├── Features/
│   ├── AppFeature.swift       # Root TCA reducer (onboarding, home, Settings sheet)
│   ├── Chat/                  # Thread, streaming, chat history persistence
│   │   ├── Domain/
│   │   ├── Application/       # ChatFeature, ChatTurnEngine
│   │   ├── Infrastructure/
│   │   └── Presenter/
│   ├── Home/                  # Post-onboarding workspace (composer, catalog, sidebar)
│   │   ├── Domain/
│   │   ├── Application/       # HomeFeature + ChatHistory, ModelCatalog, Composer child reducers
│   │   ├── Infrastructure/
│   │   └── Presenter/         # HomeView and workspace chrome
│   ├── Onboarding/            # First-run onboarding feature
│   │   ├── Application/
│   │   ├── Domain/
│   │   ├── Infrastructure/
│   │   └── Presenter/
│   └── Settings/              # API key settings sheet (composed at AppFeature level)
│       ├── Application/
│       └── Presenter/
├── Externals/                 # External integrations (Networking, Preference, Security)
└── Shared/                    # Theme + UI primitives only
    ├── Theme/                 # Palette, typography, app theme preference
    └── UI/                    # Buttons, badges, patterns, backgrounds
OpenZoneTests/                 # Unit tests
OpenZoneUITests/               # UI tests
```

See [docs/architecture/modules.md](docs/architecture/modules.md) for feature/shared ownership rules and the future internal-library path. See [docs/architecture/swift-6-strictness.md](docs/architecture/swift-6-strictness.md) for concurrency and memory-safety rules.

## 📚 Documentation

| Topic | Location |
|-------|----------|
| Doc index | [docs/README.md](docs/README.md) |
| Contributing & issues | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Agent / skill configuration | [AGENTS.md](AGENTS.md) → [docs/agents/](docs/agents/) |
| Domain glossaries (multi-context) | [CONTEXT-MAP.md](CONTEXT-MAP.md) → `docs/contexts/*/CONTEXT.md` |
| Architecture decisions (ADRs) | `docs/adr/` (created as decisions are recorded) |
| Module & TCA layout | [docs/architecture/modules.md](docs/architecture/modules.md) |
| Swift 6 concurrency & safety | [docs/architecture/swift-6-strictness.md](docs/architecture/swift-6-strictness.md) |

Issues and PRDs are tracked on [GitHub Issues](https://github.com/bengidev/openzone-swifters/issues). See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md) for CLI conventions.

## 🤝 Contributing

Contributions welcome. Open an issue or PR on `bengidev/openzone-swifters`. See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

[MIT](LICENSE) © [bengidev](https://github.com/bengidev)
