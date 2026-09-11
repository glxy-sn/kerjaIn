import AppIntents

struct KerjaInShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddJobApplicationIntent(),
            phrases: [
                "Add job application in \(.applicationName)",
                "Track new job in \(.applicationName)"
            ],
            shortTitle: "Add Job Application",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: GetJobStatsIntent(),
            phrases: [
                "Job stats in \(.applicationName)",
                "How many applications in \(.applicationName)"
            ],
            shortTitle: "Job Stats",
            systemImageName: "chart.bar.fill"
        )
    }
}
