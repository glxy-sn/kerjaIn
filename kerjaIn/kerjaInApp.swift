import SwiftUI

@main
struct kerjaInApp: App {
    @State private var service = MLXInferenceService.shared

    var body: some Scene {
        WindowGroup {
            if service.loadState.isReady {
                RootView()
            } else {
                ModelLoadingView()
                    .task { await service.loadSelectedModel() }
            }
        }
    }
}
