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
├── OpenZoneApp.swift          # App entry, routing, SwiftData ModelContainer
├── ContentView.swift          # Temporary main app content after onboarding
├── Item.swift                 # SwiftData @Model scaffold
├── Features/
│   ├── AppFeature.swift       # Root TCA reducer
│   └── Onboarding/            # First-run onboarding feature
│       ├── Application/       # TCA reducer, state, actions, orchestration
│       ├── Domain/            # Onboarding pages and value types
│       ├── Infrastructure/    # SwiftData progress persistence client
│       └── Presenter/         # SwiftUI onboarding screens backed by StoreOf<OnboardingFeature>
└── Shared/                    # App-wide theme and reusable UI primitives
    ├── Theme/
    └── UI/
OpenZoneTests/                 # Unit tests
OpenZoneUITests/               # UI tests
```

See [docs/architecture/modules.md](docs/architecture/modules.md) for feature/shared ownership rules and the future internal-library path. See [docs/architecture/swift-6-strictness.md](docs/architecture/swift-6-strictness.md) for concurrency and memory-safety rules.

## 🤝 Contributing

Contributions welcome. Open an issue or PR. See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

[MIT](LICENSE) © [bengidev](https://github.com/bengidev)
