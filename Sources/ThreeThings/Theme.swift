import SwiftUI

/// The two looks: clean white, and a warm dark grey with off-white text.
struct Theme {
    let background: Color
    let sidebar: Color
    let card: Color
    let text: Color
    let secondary: Color
    let faint: Color
    let hairline: Color
    let fill: Color
    let fillStrong: Color
    /// Behind missed tasks, and their "Missed" label.
    let missedFill: Color
    let missedLabel: Color
    let isDark: Bool

    static let light = Theme(
        background: .white,
        sidebar: .white,
        card: .white,
        text: Color(hex: 0x1A1A19),
        secondary: Color(hex: 0x73726C),
        faint: Color(hex: 0xB4B2AC),
        hairline: Color.black.opacity(0.07),
        fill: Color.black.opacity(0.04),
        fillStrong: Color.black.opacity(0.08),
        missedFill: Color(hex: 0xF8F2EA),
        missedLabel: Color(hex: 0xA2652F),
        isDark: false
    )

    static let dark = Theme(
        background: Color(hex: 0x262624),
        sidebar: Color(hex: 0x1F1E1D),
        card: Color(hex: 0x30302E),
        text: Color(hex: 0xF5F4EE),
        secondary: Color(hex: 0xB7B5A9),
        faint: Color(hex: 0x6F6D66),
        hairline: Color.white.opacity(0.08),
        fill: Color.white.opacity(0.05),
        fillStrong: Color.white.opacity(0.10),
        missedFill: Color(hex: 0x312C26),
        missedLabel: Color(hex: 0xD9A066),
        isDark: true
    )
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
