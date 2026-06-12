import SwiftUI

/// Theme preference: system, light, or dark.
enum SharedAppTheme: String, Equatable, Sendable {
    case system
    case light
    case dark

    func resolveColorScheme(_ systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    var next: SharedAppTheme {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var isDark: Bool {
        self == .dark
    }
}

private struct SharedAppThemeKey: EnvironmentKey {
    static let defaultValue: SharedAppTheme = .system
}

extension EnvironmentValues {
    var sharedAppTheme: SharedAppTheme {
        get { self[SharedAppThemeKey.self] }
        set { self[SharedAppThemeKey.self] = newValue }
    }
}
