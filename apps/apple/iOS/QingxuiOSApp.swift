import SwiftUI
import UIKit

@main
struct QingxuiOSApp: App {
  @StateObject private var store = AppStore()
  @StateObject private var rssStore = RSSStore()
  @StateObject private var updateChecker = AppUpdateChecker()

  init() {
    if #unavailable(iOS 26.0) {
      let appearance = UITabBarAppearance()
      appearance.configureWithTransparentBackground()
      appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
      appearance.backgroundColor = .clear
      appearance.shadowColor = UIColor.separator.withAlphaComponent(0.18)
      UITabBar.appearance().standardAppearance = appearance
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
  }

  var body: some Scene {
    WindowGroup {
      iOSRootView()
        .environmentObject(store)
        .environmentObject(rssStore)
        .environmentObject(updateChecker)
    }
    .backgroundTask(.appRefresh(RSSBackgroundRefresh.identifier)) {
      await rssStore.refresh()
      RSSBackgroundRefresh.schedule()
    }
  }
}

private struct iOSRootView: View {
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var updateChecker: AppUpdateChecker
  @EnvironmentObject private var rssStore: RSSStore
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @State private var selection = AppTab.today
  @State private var showingLaunchExperience = true
  @State private var availableUpdate: QingxuRelease?
  @State private var showingDeveloperTools = false
  @State private var developerToolsDetent: PresentationDetent = .medium
  @AppStorage(QingxuPreferenceKey.moduleOrder) private var moduleOrder = QingxuModuleOrder.defaultValue

  var body: some View {
    ZStack {
      QingxuPalette.background.ignoresSafeArea()

      TabView(selection: $selection) {
        ForEach(visibleTabs) { tab in
          tabContent(tab)
            .tabItem {
              TempoTabLabel(tab: tab, isSelected: selection == tab)
            }
            .tag(tab)
        }
      }
      .tint(QingxuPalette.accent)
      .disabled(showingLaunchExperience)
      .background {
        DeveloperToolsTabGestureBridge {
          developerToolsDetent = .medium
          showingDeveloperTools = true
        }
        .frame(width: 0, height: 0)
      }

      if showingLaunchExperience {
        QingxuLaunchExperience {
          showingLaunchExperience = false
          checkForUpdates()
        }
        .zIndex(10)
      }
    }
    .onChange(of: selection) { _ in
      guard !showingLaunchExperience else { return }
      let feedback = UIImpactFeedbackGenerator(style: .soft)
      feedback.prepare()
      feedback.impactOccurred(intensity: 0.78)
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        consumePendingWidgetDestination()
        Task {
          await store.syncNow()
          await rssStore.syncNow()
          await rssStore.refreshIfNeeded()
        }
      } else if phase == .background {
        RSSBackgroundRefresh.schedule()
      }
    }
    .onOpenURL { url in
      switch url.host {
      case "today": selection = .today
      case "inbox": selection = .inbox
      case "pomodoro": selection = .pomodoro
      case "rss": selection = .rss
      case "settings": selection = .settings
      default: selection = .today
      }
    }
    .alert(item: $availableUpdate) { release in
      Alert(
        title: Text("发现新版本 v\(release.version)"),
        message: Text(updateMessage(release)),
        primaryButton: .default(Text("直接下载")) {
          openURL(release.iOSAsset?.browserDownloadURL ?? release.htmlURL)
        },
        secondaryButton: .cancel(Text("稍后"))
      )
    }
    .sheet(isPresented: $showingDeveloperTools) {
      DeveloperToolsView(selectedDetent: $developerToolsDetent)
        .environmentObject(store)
        .environmentObject(updateChecker)
        .presentationDetents([.medium, .large], selection: $developerToolsDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }
    .onAppear {
      consumePendingWidgetDestination()
      RSSBackgroundRefresh.schedule()
    }
  }

  private var visibleTabs: [AppTab] {
    QingxuNavigationPolicy.visibleTabs(order: QingxuModuleOrder.decode(moduleOrder))
  }

  @ViewBuilder
  private func tabContent(_ tab: AppTab) -> some View {
    switch tab {
    case .inbox: TaskListScreen(scope: .inbox)
    case .today: TaskListScreen(scope: .today)
    case .pomodoro: PomodoroScreen()
    case .rss: RSSScreen(store: rssStore)
    case .settings: SettingsScreen()
    }
  }

  private func consumePendingWidgetDestination() {
    let defaults = UserDefaults(suiteName: "group.one.darker.qingxu")
    guard let rawValue = defaults?.string(forKey: "pendingWidgetDestination") else { return }
    defaults?.removeObject(forKey: "pendingWidgetDestination")
    switch rawValue {
    case "pomodoro": selection = .pomodoro
    default: selection = .today
    }
  }

  private func checkForUpdates() {
    Task {
      if let release = await updateChecker.check() {
        availableUpdate = release
      }
    }
  }

  private func updateMessage(_ release: QingxuRelease) -> String {
    let notes = release.body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !notes.isEmpty else { return "新版本已经发布，可前往 GitHub 下载 IPA。" }
    return String(notes.prefix(240))
  }
}

private struct DeveloperToolsTabGestureBridge: UIViewControllerRepresentable {
  let onReveal: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onReveal: onReveal) }

  func makeUIViewController(context: Context) -> Controller {
    let controller = Controller()
    controller.onResolveTabBar = { [weak coordinator = context.coordinator] tabBar in
      coordinator?.install(on: tabBar)
    }
    return controller
  }

  func updateUIViewController(_ controller: Controller, context: Context) {
    context.coordinator.onReveal = onReveal
    controller.resolveTabBarWhenReady()
  }

  final class Controller: UIViewController {
    var onResolveTabBar: ((UITabBar) -> Void)?

    override func loadView() {
      view = UIView(frame: .zero)
      view.isUserInteractionEnabled = false
      view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      resolveTabBarWhenReady()
    }

    func resolveTabBarWhenReady() {
      DispatchQueue.main.async { [weak self] in
        guard let self, let tabBar = tabBarController?.tabBar
          ?? view.window?.rootViewController?.findDeveloperToolsTabBarController()?.tabBar
        else { return }
        onResolveTabBar?(tabBar)
      }
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onReveal: () -> Void
    private weak var installedTabBar: UITabBar?
    private weak var tapRecognizer: UITapGestureRecognizer?
    private weak var longPressRecognizer: UILongPressGestureRecognizer?

    init(onReveal: @escaping () -> Void) {
      self.onReveal = onReveal
    }

    func install(on tabBar: UITabBar) {
      guard installedTabBar !== tabBar else { return }
      uninstall()

      let tap = UITapGestureRecognizer(target: self, action: #selector(handleFourTaps(_:)))
      tap.numberOfTapsRequired = 4
      tap.cancelsTouchesInView = false
      tap.delegate = self

      let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      longPress.minimumPressDuration = 0.65
      longPress.cancelsTouchesInView = false
      longPress.delegate = self

      tabBar.addGestureRecognizer(tap)
      tabBar.addGestureRecognizer(longPress)
      installedTabBar = tabBar
      tapRecognizer = tap
      longPressRecognizer = longPress
    }

    private func uninstall() {
      if let tapRecognizer { installedTabBar?.removeGestureRecognizer(tapRecognizer) }
      if let longPressRecognizer { installedTabBar?.removeGestureRecognizer(longPressRecognizer) }
    }

    @objc private func handleFourTaps(_ recognizer: UITapGestureRecognizer) {
      guard recognizer.state == .ended, isSettingsItem(at: recognizer.location(in: recognizer.view)) else { return }
      reveal()
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
      guard recognizer.state == .began, isSettingsItem(at: recognizer.location(in: recognizer.view)) else { return }
      reveal()
    }

    private func reveal() {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      onReveal()
    }

    private func isSettingsItem(at point: CGPoint) -> Bool {
      guard let tabBar = installedTabBar,
            let items = tabBar.items,
            !items.isEmpty,
            tabBar.bounds.width > 0 else { return false }
      let rawIndex = Int((point.x / tabBar.bounds.width) * CGFloat(items.count))
      let visualIndex = min(items.count - 1, max(0, rawIndex))
      let index = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
        ? items.count - 1 - visualIndex
        : visualIndex
      return items[index].title == AppTab.settings.title
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
  }
}

private extension UIViewController {
  func findDeveloperToolsTabBarController() -> UITabBarController? {
    if let tabController = self as? UITabBarController { return tabController }
    for child in children {
      if let tabController = child.findDeveloperToolsTabBarController() { return tabController }
    }
    if let presentedViewController {
      return presentedViewController.findDeveloperToolsTabBarController()
    }
    return nil
  }
}

private struct TempoTabLabel: View {
  let tab: AppTab
  let isSelected: Bool

  var body: some View {
    Label {
      Text(tab.title)
        .fontWeight(isSelected ? .semibold : .regular)
    } icon: {
      Image(systemName: tab.symbol)
        .symbolVariant(isSelected ? .fill : .none)
        .fontWeight(isSelected ? .semibold : .regular)
        .scaleEffect(isSelected ? 1.14 : 1)
        .offset(y: isSelected ? -1 : 0)
        .symbolEffect(.bounce, value: isSelected)
    }
    .contentTransition(.symbolEffect(.replace))
    .animation(.snappy(duration: 0.28, extraBounce: 0.08), value: isSelected)
  }
}
