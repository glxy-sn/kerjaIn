import WidgetKit
import SwiftUI

// Add @main back after moving this file to the Widget Extension target
@main
struct KerjaInWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        RecentAppsWidget()
    }
}
