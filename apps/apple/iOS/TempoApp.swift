import SwiftUI
import UIKit

@main
struct TempoApp: App {
  @UIApplicationDelegateAdaptor(TempoRuntimeAppDelegate.self) private var runtimeDelegate
  @StateObject private var store = AppStore()
  @StateObject private var rssStore = RSSStore()
  @StateObject private var updateChecker = AppUpdateChecker()

  init() {
    // Configure the selected state before SwiftUI creates the first tab bar.
    // This avoids the launch transition briefly rendering the selected item
    // with UIKit's default dark tint and switching to Tempo blue later.
    UITabBar.appearance().tintColor = .tempoTabAccent
    UITabBar.appearance().unselectedItemTintColor = .secondaryLabel
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
  @State private var availableUpdate: TempoRelease?
  @State private var showingDeveloperTools = false
  @State private var developerToolsDetent: PresentationDetent = .medium
  @AppStorage(TempoPreferenceKey.moduleOrder) private var moduleOrder = TempoModuleOrder.defaultValue

  var body: some View {
    ZStack {
      TempoPalette.background.ignoresSafeArea()

      TabView(selection: $selection) {
        ForEach(visibleTabs) { tab in
          tabContent(tab)
            .tabItem {
              TempoTabLabel(tab: tab, isSelected: selection == tab)
            }
            .tag(tab)
        }
      }
      .tint(TempoPalette.accent)
      .disabled(showingLaunchExperience)
      .background {
        TempoTabBarBridge(selection: selection, visibleTabs: visibleTabs) {
          developerToolsDetent = .medium
          showingDeveloperTools = true
        }
        .frame(width: 0, height: 0)
      }

      if showingLaunchExperience {
        TempoLaunchExperience {
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
    TempoNavigationPolicy.visibleTabs(order: TempoModuleOrder.decode(moduleOrder))
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

  private func updateMessage(_ release: TempoRelease) -> String {
    let notes = release.body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !notes.isEmpty else { return "新版本已经发布，可前往 GitHub 下载 IPA。" }
    return String(notes.prefix(240))
  }
}

private struct TempoTabBarBridge: UIViewControllerRepresentable {
  let selection: AppTab
  let visibleTabs: [AppTab]
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
    context.coordinator.selection = selection
    context.coordinator.visibleTabs = visibleTabs
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
        guard let self, let tabBar = tabBarController?.tabBar
          ?? view.window?.rootViewController?.findDeveloperToolsTabBarController()?.tabBar
        else { return }
        onResolveTabBar?(tabBar)
      }
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onReveal: () -> Void
    var selection: AppTab
    var visibleTabs: [AppTab]
    private weak var installedTabBar: UITabBar?
    private weak var tapRecognizer: UITapGestureRecognizer?
    private weak var longPressRecognizer: UILongPressGestureRecognizer?

    init(onReveal: @escaping () -> Void) {
      self.onReveal = onReveal
      selection = .today
      visibleTabs = AppTab.allCases
    }

    func install(on tabBar: UITabBar) {
      guard installedTabBar !== tabBar else {
        updateSelection()
        return
      }
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
      updateSelection(animated: false)
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

    private func updateSelection(animated: Bool = true) {
      guard let tabBar = installedTabBar else { return }
      tabBar.layoutIfNeeded()
      let allControls = tabBar.subviews
        .compactMap { $0 as? UIControl }
        .sorted { $0.frame.minX < $1.frame.minX }
      let tabButtons = allControls.filter {
        NSStringFromClass(type(of: $0)).contains("TabBarButton")
      }
      let controls = tabButtons.count == visibleTabs.count ? tabButtons : Array(allControls.prefix(visibleTabs.count))
      guard controls.count == visibleTabs.count,
            let selectedIndex = visibleTabs.firstIndex(of: selection) else { return }

      for (index, control) in controls.enumerated() {
        let tag = 0x54454D50
        let pill: UIView
        if let existing = control.viewWithTag(tag) {
          pill = existing
        } else {
          let created = UIView(frame: .zero)
          created.tag = tag
          created.isUserInteractionEnabled = false
          created.backgroundColor = UIColor.tempoTabSelectionFill
          created.layer.cornerCurve = .continuous
          created.layer.borderWidth = 0.7
          created.layer.borderColor = UIColor.tempoTabSelectionStroke.cgColor
          created.layer.shadowColor = UIColor.black.cgColor
          created.layer.shadowOffset = CGSize(width: 0, height: 3)
          created.layer.shadowRadius = 8
          created.layer.shadowOpacity = 0
          control.insertSubview(created, at: 0)
          pill = created
        }

        let targetFrame = control.bounds.insetBy(dx: 3, dy: 3)
        pill.frame = targetFrame
        pill.layer.cornerRadius = max(18, targetFrame.height / 2)
        let selected = index == selectedIndex
        let changes = {
          pill.alpha = selected ? 1 : 0
          pill.transform = selected ? .identity : CGAffineTransform(scaleX: 0.66, y: 0.82)
          pill.layer.shadowOpacity = selected ? 0.10 : 0
          control.transform = selected ? CGAffineTransform(scaleX: 1.065, y: 1.065) : .identity
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
          UIViewPropertyAnimator(duration: 0.42, dampingRatio: 0.78, animations: changes).startAnimation()
        } else {
          changes()
        }
      }
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

    deinit { uninstall() }
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

private extension UIColor {
  static let tempoTabAccent = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.49, green: 0.65, blue: 1.00, alpha: 1)
      : UIColor(red: 0.20, green: 0.41, blue: 0.91, alpha: 1)
  }

  static let tempoTabSelectionFill = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.20, green: 0.29, blue: 0.46, alpha: 0.74)
      : UIColor(red: 0.88, green: 0.92, blue: 1.00, alpha: 0.94)
  }

  static let tempoTabSelectionStroke = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.49, green: 0.65, blue: 1.00, alpha: 0.32)
      : UIColor(red: 0.20, green: 0.41, blue: 0.91, alpha: 0.18)
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
