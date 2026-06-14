import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "chart.line.uptrend.xyaxis"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    @MainActor
    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .today:
            TodayView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}

@MainActor
struct AppView: View {
    @Environment(AuthSessionStore.self) private var auth
    @State private var selectedTab: AppTab = .today

    var body: some View {
        Group {
            if auth.requiresAuthentication && !auth.isAuthenticated {
                LoginView()
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        NavigationStack {
                            tab.makeContentView()
                        }
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .tag(tab)
                    }
                }
            }
        }
        .task {
            await auth.restore()
        }
    }
}

#Preview("Loaded") {
    let environment = AppEnvironment()
    AppView()
        .environment(environment.auth)
        .environment(AppStore.previewLoaded)
}
