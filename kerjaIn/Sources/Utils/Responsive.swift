import SwiftUI

enum Screen {
    static var width: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.width
        #else
        800
        #endif
    }
    static var height: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.height
        #else
        600
        #endif
    }
}

extension BinaryFloatingPoint {
    func wPercent() -> CGFloat { Screen.width * CGFloat(self) }
    func hPercent() -> CGFloat { Screen.height * CGFloat(self) }
}
