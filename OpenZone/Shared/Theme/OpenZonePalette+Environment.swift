import SwiftUI

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: OpenZonePalette = .resolve(.light)
}

extension EnvironmentValues {
    public var palette: OpenZonePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
