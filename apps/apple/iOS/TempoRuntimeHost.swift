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
  @State private var timerDragOffset: CGFloat = 0
  let route: AppTab

  private let timerSegmentWidth: CGFloat = 88
  private let timerSegmentTravel: CGFloat = 90

  var body: some View {
    ZStack {
      HStack(spacing: 10) {
        if route == .inbox || route == .rss {
          chromeButton("magnifyingglass", command: "search")
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
  }

  private var timerDirectionControl: some View {
    Group {
      if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: 4) {
          ZStack(alignment: .leading) {
            Color.clear
              .frame(width: 186, height: 48)
              .glassEffect(.regular.interactive(), in: .capsule)

            Color.clear
              .frame(width: timerSegmentWidth, height: 40)
              .glassEffect(
                .regular.tint(TempoPalette.ink.opacity(0.10)).interactive(),
                in: .capsule
              )
              .offset(x: 4 + timerSelectionOffset + timerDragOffset)
              .allowsHitTesting(false)

            timerDirectionLabels
          }
        }
      } else {
        ZStack(alignment: .leading) {
          Capsule()
            .fill(.ultraThinMaterial)
            .frame(width: 186, height: 48)

          Capsule()
            .fill(TempoPalette.surface.opacity(0.82))
            .frame(width: timerSegmentWidth, height: 40)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .offset(x: 4 + timerSelectionOffset + timerDragOffset)
            .allowsHitTesting(false)

          timerDirectionLabels
        }
      }
    }
    .frame(width: 186, height: 48)
    .simultaneousGesture(timerDirectionDragGesture)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("计时方式")
  }

  private var timerDirectionLabels: some View {
    HStack(spacing: 2) {
      ForEach(PomodoroTimerDirection.allCases) { direction in
        Button {
          selectTimerDirection(direction)
        } label: {
          Text(direction.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(
              timerVisualDirection == direction
                ? TempoPalette.ink
                : TempoPalette.quiet
            )
            .frame(width: timerSegmentWidth, height: 40)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
          store.pomodoro.timerDirection == direction ? .isSelected : []
        )
      }
    }
    .padding(4)
  }

  private var timerSelectionOffset: CGFloat {
    store.pomodoro.timerDirection == .countdown ? 0 : timerSegmentTravel
  }

  private var timerVisualDirection: PomodoroTimerDirection {
    timerSelectionOffset + timerDragOffset >= timerSegmentTravel / 2
      ? .countUp
      : .countdown
  }

  private var timerDirectionDragGesture: some Gesture {
    DragGesture(minimumDistance: 6, coordinateSpace: .local)
      .onChanged { value in
        let translation = value.translation.width
        if store.pomodoro.timerDirection == .countdown {
          timerDragOffset = min(timerSegmentTravel, max(0, translation))
        } else {
          timerDragOffset = max(-timerSegmentTravel, min(0, translation))
        }
      }
      .onEnded { value in
        let projected = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
          ? value.predictedEndTranslation.width
          : value.translation.width
        let target: PomodoroTimerDirection
        if store.pomodoro.timerDirection == .countdown {
          target = projected > timerSegmentTravel * 0.34 ? .countUp : .countdown
        } else {
          target = projected < -timerSegmentTravel * 0.34 ? .countdown : .countUp
        }
        let changed = store.pomodoro.timerDirection != target
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.12)) {
          timerDragOffset = 0
          if changed {
            store.setPomodoroTimerDirection(target)
          }
        }
        if changed {
          UISelectionFeedbackGenerator().selectionChanged()
        }
      }
  }

  private func selectTimerDirection(_ direction: PomodoroTimerDirection) {
    guard store.pomodoro.timerDirection != direction else { return }
    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.12)) {
      timerDragOffset = 0
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
        commandButton("搜索任务", symbol: "magnifyingglass", command: "search")
        Divider()
        commandButton("显示已完成", symbol: "checkmark.circle", command: "showCompleted")
        commandButton("隐藏已完成", symbol: "circle", command: "hideCompleted")
      case .today:
        commandButton("安排任务", symbol: "calendar.badge.plus", command: "newTask")
        commandButton("搜索任务", symbol: "magnifyingglass", command: "search")
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
        commandButton("搜索文章", symbol: "magnifyingglass", command: "search")
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
