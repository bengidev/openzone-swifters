import SwiftUI

/// Theme preference: system, light, or dark.
public enum AppTheme: String, Equatable, Sendable {
    case system
    case light
    case dark

    public func resolveColorScheme(_ systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var next: AppTheme {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var isDark: Bool {
        self == .dark
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    public var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
