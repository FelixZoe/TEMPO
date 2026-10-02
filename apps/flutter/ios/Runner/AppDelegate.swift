import Flutter
import UIKit

enum TempoTab: String, CaseIterable, Hashable {
  case inbox
  case today
  case pomodoro
  case settings

  var title: String {
    switch self {
    case .inbox: return "收集箱"
    case .today: return "今天"
    case .pomodoro: return "番茄钟"
    case .settings: return "设置"
    }
  }

  var systemImage: String {
    switch self {
    case .inbox: return "tray"
    case .today: return "sun.max"
    case .pomodoro: return "timer"
    case .settings: return "gearshape"
    }
  }
}

enum TempoThemeMode: String {
  case system
  case light
  case dark
}

final class NativeNavigationBridge {
  private var channel: FlutterMethodChannel?
  private weak var tabBarController: TempoTabBarController?
  private var selectedTab = TempoTab.today
  private var themeMode = TempoThemeMode.system

  func connect(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "one.darker.qingxu/navigation",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setSelectedTab":
        guard
          let rawValue = call.arguments as? String,
          let tab = TempoTab(rawValue: rawValue)
        else {
          result(
            FlutterError(
              code: "invalid_tab",
              message: "Flutter requested an unsupported native tab.",
              details: call.arguments
            )
          )
          return
        }
        DispatchQueue.main.async {
          self?.selectedTab = tab
          self?.tabBarController?.select(tab)
        }
        result(nil)
      case "setThemeMode":
        guard
          let rawValue = call.arguments as? String,
          let mode = TempoThemeMode(rawValue: rawValue)
        else {
          result(
            FlutterError(
              code: "invalid_theme_mode",
              message: "Flutter requested an unsupported native theme mode.",
              details: call.arguments
            )
          )
          return
        }
        DispatchQueue.main.async {
          self?.themeMode = mode
          self?.tabBarController?.applyThemeMode(mode)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func install(tabBarController: TempoTabBarController) {
    self.tabBarController = tabBarController
    tabBarController.select(selectedTab)
    tabBarController.applyThemeMode(themeMode)
  }

  func userSelected(_ tab: TempoTab) {
    selectedTab = tab
    channel?.invokeMethod("selectTab", arguments: tab.rawValue)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  let navigationBridge = NativeNavigationBridge()
  let systemFeaturesBridge = IOSSystemFeaturesBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    navigationBridge.connect(to: engineBridge.applicationRegistrar.messenger())
    systemFeaturesBridge.connect(to: engineBridge.applicationRegistrar.messenger())
  }
}
