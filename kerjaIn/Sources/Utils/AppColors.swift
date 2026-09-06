import SwiftUI

extension Color {
    // Backgrounds
    static let appBackground     = Color(hex: "f2f2f2")
    static let sidebarBackground = Color(hex: "fbfbfb")
    static let fieldBackground   = Color(hex: "fafafa")
    static let hoverBackground   = Color(hex: "f4f4f4")

    // Ink levels
    static let inkPrimary   = Color(hex: "1a1a1a")
    static let inkSecondary = Color(hex: "6b6b6b")
    static let inkTertiary  = Color(hex: "9a9a9a")

    // Separators
    static let appSeparator      = Color(hex: "e6e6e6")
    static let lightSeparator    = Color(hex: "f0f0f0")

    // Status — foreground
    static let statusApplied   = Color(hex: "0a66c2")
    static let statusInterview = Color(hex: "c76b00")
    static let statusOffer     = Color(hex: "1a8f30")
    static let statusRejected  = Color(hex: "c0392b")
    static let statusClosed    = Color(hex: "777777")

    // Status — background
    static let statusAppliedBg   = Color(hex: "e8f0fa")
    static let statusInterviewBg = Color(hex: "fdf1e3")
    static let statusOfferBg     = Color(hex: "eaf6ec")
    static let statusRejectedBg  = Color(hex: "fbeae8")
    static let statusClosedBg    = Color(hex: "eeeeee")

    // Legacy cross-platform (kept for compatibility)
    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(hex: "f7f7f7")
        #endif
    }

    static var chipBackground: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemFill)
        #else
        Color(hex: "eeeeee")
        #endif
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}
