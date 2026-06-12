import SwiftUI

private struct SharedPaletteKey: EnvironmentKey {
    static let defaultValue: SharedOpenZonePalette = .resolve(.light)
}

extension EnvironmentValues {
    var sharedPalette: SharedOpenZonePalette {
        get { self[SharedPaletteKey.self] }
        set { self[SharedPaletteKey.self] = newValue }
    }
}
