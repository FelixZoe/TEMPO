import SwiftUI

@main
struct QingxumacOSApp: App {
  @StateObject private var store = AppStore()
  @StateObject private var rssStore = RSSStore()
  @StateObject private var floatingPanel = MacFloatingPanelController()

  var body: some Scene {
    WindowGroup {
      MacRootView(floatingPanel: floatingPanel)
        .environmentObject(store)
        .environmentObject(rssStore)
        .frame(minWidth: 860, minHeight: 600)
    }
    .windowStyle(.titleBar)

    Settings {
      MacPreferencesView()
        .environmentObject(store)
        .frame(width: 520, height: 420)
    }
  }
}

private struct MacRootView: View {
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var rssStore: RSSStore
  @ObservedObject var floatingPanel: MacFloatingPanelController
  @State private var selection: AppTab? = .inbox

  private var sidebarTabs: [AppTab] {
    AppTab.allCases
  }

  var body: some View {
    NavigationSplitView {
      List(sidebarTabs, selection: $selection) { tab in
        Label(tab.title, systemImage: tab.symbol).tag(tab)
      }
      .navigationTitle("序舱")
      .listStyle(.sidebar)
      .frame(minWidth: 190)
    } detail: {
      switch selection ?? .inbox {
      case .inbox: TaskListScreen(scope: .inbox)
      case .today: TaskListScreen(scope: .today)
      case .pomodoro: PomodoroScreen()
      case .rss: RSSScreen(store: rssStore)
      case .settings: SettingsScreen()
      }
    }
    .tint(QingxuPalette.accent)
    .onAppear {
      floatingPanel.present(store: store)
    }
  }
}

private struct MacPreferencesView: View {
  var body: some View {
    SettingsScreen()
  }
}
