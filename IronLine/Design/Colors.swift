import SwiftUI

/// Dark, premium, data-dense — WHOOP x UFC x Gran Turismo. Tune freely; these are starting values.
extension Theme {
    enum Color {
        static let background = SwiftUI.Color(hex: "0A0A0C")
        static let surface = SwiftUI.Color(hex: "16161A")
        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color(hex: "9A9AA2")

        static let accent = SwiftUI.Color(hex: "2E6BFF")   // electric blue — primary actions
        static let intensity = SwiftUI.Color(hex: "FF3B30") // red — effort/duels
        static let gold = SwiftUI.Color(hex: "FFC93C")      // PRs
        static let danger = intensity
        static let success = SwiftUI.Color(hex: "34C759")
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
