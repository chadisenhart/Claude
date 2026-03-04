import SwiftUI

struct MainTabView: View {
    var profile: AthleteProfile

    var body: some View {
        TabView {
            DashboardView(profile: profile)
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }

            WeekView(profile: profile)
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }

            ProgressView(profile: profile)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(profile: profile)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
