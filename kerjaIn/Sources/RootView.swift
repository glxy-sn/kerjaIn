import SwiftUI

struct RootView: View {
    @State private var router = Router()
    @State private var container = DIContainer()

    var body: some View {
        @Bindable var router = router
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selectedTab: $router.selectedTab)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            switch router.selectedTab {
            case .home:
                NavigationStack(path: $router.homePath) {
                    container.makeHomeView()
                }
            case .cvGenerator:
                NavigationStack {
                    container.makeCVGeneratorView()
                }
            case .history:     container.makeHistoryView()
            case .profile:     container.makeProfileView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(router)
        .onOpenURL { url in
            guard url.scheme == "kerjaIn" else { return }
            if url.host == "generate" {
                router.selectedTab = .cvGenerator
            } else {
                router.selectedTab = .history
            }
        }
    }
}
