import SwiftUI
import Observation

enum Tab {
    case home, cvGenerator, history, profile
}

enum Route: Hashable {
    case historyDetail(id: String)
    case cvPreview
}

@Observable
final class Router {
    var selectedTab: Tab = .home
    var homePath = NavigationPath()
    var historyPath = NavigationPath()

    func push(_ route: Route, tab: Tab = .home) {
        switch tab {
        case .home:    homePath.append(route)
        case .history: historyPath.append(route)
        default:       break
        }
    }

    func pop(from tab: Tab = .home) {
        switch tab {
        case .home:    if !homePath.isEmpty { homePath.removeLast() }
        case .history: if !historyPath.isEmpty { historyPath.removeLast() }
        default:       break
        }
    }

    func popToRoot(tab: Tab = .home) {
        switch tab {
        case .home:    homePath = NavigationPath()
        case .history: historyPath = NavigationPath()
        default:       break
        }
    }
}
