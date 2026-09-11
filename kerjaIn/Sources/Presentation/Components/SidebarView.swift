import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: Tab
    @State private var userName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title
            Text("kerjaIn")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 18)

            // Main navigation
            SidebarSectionLabel("MENU")
            VStack(spacing: 2) {
                SidebarNavItem(icon: "house", label: "Home",
                               isActive: selectedTab == .home) { selectedTab = .home }
                SidebarNavItem(icon: "clock.arrow.circlepath", label: "History",
                               isActive: selectedTab == .history) { selectedTab = .history }
                SidebarNavItem(icon: "person.circle", label: "Profile",
                               isActive: selectedTab == .profile) { selectedTab = .profile }
            }
            .padding(.horizontal, 12)

            // Tools section
            SidebarSectionLabel("TOOLS")
                .padding(.top, 10)
            VStack(spacing: 2) {
                SidebarNavItem(icon: "character.textbox.badge.sparkles", label: "CV Generator",
                               isActive: selectedTab == .cvGenerator) { selectedTab = .cvGenerator }
            }
            .padding(.horizontal, 12)

            Spacer()
            Divider()

            Button { selectedTab = .profile } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.inkPrimary)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(userName.isEmpty ? "U" : String(userName.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(userName.isEmpty ? "User" : userName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Profile & Settings")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color.sidebarBackground)
        .onAppear {
            userName = ProfileRepositoryImpl(dataSource: LocalDataSource()).getProfile().name
        }
    }
}

private struct SidebarSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.inkSecondary.opacity(0.6))
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
    }
}

private struct SidebarNavItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 17)
                    .opacity(isActive ? 1.0 : 0.7)
                Text(label)
                    .font(.system(size: 14.5, weight: isActive ? .semibold : .medium))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.appSeparator, lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(Color.inkPrimary)
        }
        .buttonStyle(.plain)
    }
}
