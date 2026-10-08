import SwiftUI
import TempoRuntime
import UIKit

final class TempoRuntimeAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    ReactNativeHostManager.shared.initialize()
    return true
  }
}

struct TempoRuntimeScreen: View {
  @State private var settingsVisible = false
  let route: AppTab

  var body: some View {
    ZStack(alignment: .top) {
      ReactNativeView(
        moduleName: "main",
        initialProps: [
          "route": route.runtimeRoute,
          "locale": Locale.current.identifier,
        ]
      )
      .ignoresSafeArea(edges: .bottom)
      .opacity(route == .settings ? (settingsVisible ? 1 : 0) : 1)
      .offset(y: route == .settings && !settingsVisible ? 10 : 0)

      TempoRuntimeChrome(route: route)
    }
    .onAppear {
      guard route == .settings else { return }
      settingsVisible = false
      DispatchQueue.main.async {
        withAnimation(.easeOut(duration: 0.28)) {
          settingsVisible = true
        }
      }
    }
    .onDisappear {
      guard route == .settings else { return }
      settingsVisible = false
    }
  }
}

private struct TempoRuntimeChrome: View {
  @EnvironmentObject private var store: AppStore
  @State private var timerThumbX: CGFloat?
  @State private var searchExpanded = false
  @State private var searchText = ""
  @FocusState private var searchFocused: Bool
  let route: AppTab

  private let timerControlWidth: CGFloat = 186
  private let timerThumbWidth: CGFloat = 88
  private let timerLeadingX: CGFloat = 4
  private let timerTrailingX: CGFloat = 94

  var body: some View {
    ZStack {
      HStack(spacing: 10) {
        if searchExpanded || route == .inbox || route == .rss {
          searchControl
        } else if route == .pomodoro {
          chromeButton("chart.xyaxis.line", command: "statistics")
        }

        Spacer()

        if route != .settings {
          optionsMenu
        }
      }

      if route == .pomodoro {
        timerDirectionControl
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .allowsHitTesting(true)
    .onChange(of: route) { _, _ in
      closeSearch()
    }
  }

  private var searchControl: some View {
    Group {
      if searchExpanded {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(TempoPalette.quiet)

          TextField(searchPlaceholder, text: $searchText)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(TempoPalette.ink)
            .tint(TempoPalette.accent)
            .submitLabel(.search)
            .focused($searchFocused)
            .onChange(of: searchText) { _, value in
              TempoNativeRegistry.shared.sendCommand("search", payload: ["query": value])
            }

          Button(action: closeSearch) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(TempoPalette.quiet)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("关闭搜索")
        }
        .padding(.horizontal, 14)
      } else {
        Button(action: openSearch) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(TempoPalette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("搜索")
      }
    }
    .frame(width: searchExpanded ? searchExpandedWidth : 48, height: 48)
    .tempoSearchSurface()
    .animation(
      .interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.12),
      value: searchExpanded
    )
  }

  private var searchExpandedWidth: CGFloat {
    min(320, max(220, UIScreen.main.bounds.width - 104))
  }

  private var searchPlaceholder: String {
    switch route {
    case .inbox: "搜索收集箱"
    case .today: "搜索这一天"
    case .rss: "搜索标题、来源或摘要"
    default: "搜索"
    }
  }

  private func openSearch() {
    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
      searchExpanded = true
    }
    TempoNativeRegistry.shared.sendCommand("search", payload: ["query": searchText])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      searchFocused = true
    }
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }

  private func closeSearch() {
    searchFocused = false
    searchText = ""
    TempoNativeRegistry.shared.sendCommand("search", payload: ["query": ""])
    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88)) {
      searchExpanded = false
    }
  }

  private var timerDirectionControl: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule()
            .stroke(TempoPalette.separator.opacity(0.28), lineWidth: 0.5)
        }

      Group {
        if #available(iOS 26.0, *) {
          Color.clear
            .glassEffect(
              .regular.tint(TempoPalette.accent.opacity(0.24)).interactive(),
              in: .capsule
            )
        } else {
          Capsule()
            .fill(TempoPalette.surface.opacity(0.88))
            .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
        }
      }
      .frame(width: timerThumbWidth, height: 40)
      .offset(x: resolvedTimerThumbX)
      .allowsHitTesting(false)

      HStack(spacing: 2) {
        ForEach(PomodoroTimerDirection.allCases) { direction in
          Text(direction.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(
              timerVisualDirection == direction
                ? TempoPalette.accent
                : TempoPalette.quiet
            )
            .frame(width: timerThumbWidth, height: 40)
        }
      }
      .padding(4)
      .allowsHitTesting(false)
    }
    .frame(width: timerControlWidth, height: 48)
    .contentShape(Capsule())
    .gesture(timerDirectionDragGesture)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("计时方式")
    .accessibilityValue(store.pomodoro.timerDirection.title)
    .accessibilityAdjustableAction { adjustment in
      switch adjustment {
      case .increment: selectTimerDirection(.countUp)
      case .decrement: selectTimerDirection(.countdown)
      @unknown default: break
      }
    }
  }

  private var restingTimerThumbX: CGFloat {
    store.pomodoro.timerDirection == .countdown ? timerLeadingX : timerTrailingX
  }

  private var resolvedTimerThumbX: CGFloat {
    timerThumbX ?? restingTimerThumbX
  }

  private var timerVisualDirection: PomodoroTimerDirection {
    resolvedTimerThumbX + timerThumbWidth / 2 < timerControlWidth / 2
      ? .countdown
      : .countUp
  }

  private var timerDirectionDragGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { value in
        timerThumbX = clampedTimerThumbX(for: value.location.x)
      }
      .onEnded { value in
        let actualX = clampedTimerThumbX(for: value.location.x)
        let projectedX = clampedTimerThumbX(for: value.predictedEndLocation.x)
        let landingX = abs(projectedX - actualX) > 5 ? projectedX : actualX
        let target: PomodoroTimerDirection = landingX + timerThumbWidth / 2 < timerControlWidth / 2
          ? .countdown
          : .countUp
        let changed = store.pomodoro.timerDirection != target
        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.84, blendDuration: 0.12)) {
          timerThumbX = nil
          if changed {
            store.setPomodoroTimerDirection(target)
          }
        }
        if changed {
          UISelectionFeedbackGenerator().selectionChanged()
        }
      }
  }

  private func clampedTimerThumbX(for touchX: CGFloat) -> CGFloat {
    min(timerTrailingX, max(timerLeadingX, touchX - timerThumbWidth / 2))
  }

  private func selectTimerDirection(_ direction: PomodoroTimerDirection) {
    guard store.pomodoro.timerDirection != direction else { return }
    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.84, blendDuration: 0.12)) {
      timerThumbX = nil
      store.setPomodoroTimerDirection(direction)
    }
    UISelectionFeedbackGenerator().selectionChanged()
  }

  private func chromeButton(_ symbol: String, command: String) -> some View {
    Button {
      TempoNativeRegistry.shared.sendCommand(command)
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    } label: {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(TempoPalette.ink)
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .tempoFloatingSurface()
    .accessibilityLabel(command == "search" ? "搜索" : command == "statistics" ? "专注统计" : "更多")
  }

  private var optionsMenu: some View {
    Menu {
      switch route {
      case .inbox:
        commandButton("记到收集箱", symbol: "square.and.pencil", command: "newTask")
        searchCommandButton("搜索任务")
        Divider()
        commandButton("显示已完成", symbol: "checkmark.circle", command: "showCompleted")
        commandButton("隐藏已完成", symbol: "circle", command: "hideCompleted")
      case .today:
        commandButton("安排任务", symbol: "calendar.badge.plus", command: "newTask")
        searchCommandButton("搜索任务")
        commandButton("回到今天", symbol: "calendar", command: "returnToday")
        Divider()
        commandButton("显示已完成", symbol: "checkmark.circle", command: "showCompleted")
        commandButton("隐藏已完成", symbol: "circle", command: "hideCompleted")
      case .pomodoro:
        commandButton("专注统计", symbol: "chart.xyaxis.line", command: "statistics")
        commandButton("重新计时", symbol: "arrow.counterclockwise", command: "resetTimer")
        Button(role: .destructive) {
          send("stopTimer")
        } label: {
          Label("结束本次计时", systemImage: "stop.fill")
        }
      case .rss:
        commandButton("添加订阅", symbol: "plus.circle", command: "addFeed")
        commandButton("刷新全部", symbol: "arrow.clockwise", command: "refreshFeeds")
        searchCommandButton("搜索文章")
        Divider()
        commandButton("全部标为已读", symbol: "checkmark.circle", command: "markAllRead")
      case .settings:
        EmptyView()
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(TempoPalette.ink)
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .tempoFloatingSurface()
    .accessibilityLabel("更多")
  }

  private func commandButton(_ title: String, symbol: String, command: String) -> some View {
    Button {
      send(command)
    } label: {
      Label(title, systemImage: symbol)
    }
  }

  private func searchCommandButton(_ title: String) -> some View {
    Button(action: openSearch) {
      Label(title, systemImage: "magnifyingglass")
    }
  }

  private func send(_ command: String) {
    TempoNativeRegistry.shared.sendCommand(command)
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }
}

private extension AppTab {
  var runtimeRoute: String {
    switch self {
    case .inbox: "inbox"
    case .today: "today"
    case .pomodoro: "focus"
    case .rss: "rss"
    case .settings: "settings"
    }
  }
}
