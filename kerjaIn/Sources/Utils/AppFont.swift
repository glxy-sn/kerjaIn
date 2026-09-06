import SwiftUI

enum AppFontStyle {
    case display, largeTitle, heading, subheading, body, caption, button

    var size: CGFloat {
        switch self {
        case .display:     return 32
        case .largeTitle:  return 34
        case .heading:     return 24
        case .subheading:  return 18
        case .body:        return 16
        case .caption:     return 12
        case .button:      return 16
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display:              return .heavy
        case .largeTitle, .heading: return .bold
        case .subheading, .button:  return .semibold
        case .body, .caption:       return .regular
        }
    }
}

extension View {
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(.system(size: style.size, weight: style.weight))
    }
}
