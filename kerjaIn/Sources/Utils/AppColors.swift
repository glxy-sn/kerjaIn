import SwiftUI
import AppKit

extension Color {

    // MARK: - Adaptive helper
    // Creates a dynamic NSColor that resolves to different hex values in light vs dark appearance.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil) { traits in
            let hex = traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: cleaned).scanHexInt64(&int)
            return NSColor(
                srgbRed: CGFloat((int >> 16) & 0xFF) / 255,
                green:   CGFloat((int >>  8) & 0xFF) / 255,
                blue:    CGFloat(int         & 0xFF) / 255,
                alpha:   1
            )
        })
    }

    // MARK: - Backgrounds
    static let appBackground     = adaptive(light: "f2f2f2", dark: "1c1c1e")
    static let sidebarBackground = adaptive(light: "fbfbfb", dark: "252525")
    static let fieldBackground   = adaptive(light: "fafafa", dark: "3a3a3c")
    static let hoverBackground   = adaptive(light: "f4f4f4", dark: "2a2a2c")
    // Card surface — replaces hard-coded Color.white on card backgrounds
    static let cardSurface       = adaptive(light: "ffffff", dark: "2c2c2e")

    // MARK: - Ink (uses system label colors for guaranteed dark-mode adaptation)
    static let inkPrimary   = Color(nsColor: .labelColor)
    static let inkSecondary = Color(nsColor: .secondaryLabelColor)
    static let inkTertiary  = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Primary action button fill
    // Stays dark in both modes so .foregroundStyle(.white) on top always works.
    static let primaryAction = Color(hex: "1a1a1a")

    // MARK: - Separators
    static let appSeparator   = Color(nsColor: .separatorColor)
    static let lightSeparator = adaptive(light: "f0f0f0", dark: "2c2c2e")

    // MARK: - Status — foreground (vivid, same in both modes)
    static let statusApplied   = Color(hex: "0a66c2")
    static let statusInterview = Color(hex: "c76b00")
    static let statusOffer     = Color(hex: "1a8f30")
    static let statusRejected  = Color(hex: "c0392b")
    static let statusClosed    = Color(hex: "777777")

    // MARK: - Status — background (adaptive)
    static let statusAppliedBg   = adaptive(light: "e8f0fa", dark: "0a2030")
    static let statusInterviewBg = adaptive(light: "fdf1e3", dark: "2a1800")
    static let statusOfferBg     = adaptive(light: "eaf6ec", dark: "0a2010")
    static let statusRejectedBg  = adaptive(light: "fbeae8", dark: "2a0a08")
    static let statusClosedBg    = adaptive(light: "eeeeee", dark: "2a2a2a")

    // MARK: - Legacy aliases
    static var cardBackground: Color { cardSurface }
    static var chipBackground: Color { adaptive(light: "eeeeee", dark: "3a3a3c") }

    // MARK: - Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}
