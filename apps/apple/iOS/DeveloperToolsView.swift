import ActivityKit
import SwiftUI
import TempoRuntime
import UIKit

struct DeveloperToolsView: View {
  @Binding var selectedDetent: PresentationDetent
  @EnvironmentObject private var store: AppStore
  @EnvironmentObject private var updateChecker: AppUpdateChecker
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @StateObject private var ota = TempoOTAInspector()
  @State private var syncing = false
  @State private var syncMessage: String?
  @State private var systemSnapshot = TempoSystemDiagnosticSnapshot.capture()
  @State private var showingOTARuntime = false

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: 18) {
          header

          LazyVGrid(columns: columns(for: proxy.size.width), spacing: 16) {
            otaCard
            syncCard
            systemCard
            appCard
          }

          ShareLink(item: diagnosticReport) {
            Label("分享脱敏诊断报告", systemImage: "square.and.arrow.up")
              .font(.body.weight(.semibold))
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(TempoPalette.ink, in: Capsule())
              .foregroundStyle(TempoPalette.background)
          }
          .buttonStyle(.plain)

          Text("开发者工具不会显示或导出同步密钥、AI 密钥和天气密钥。新增原生依赖、权限、小组件或灵动岛能力仍需要重新构建 IPA。")
            .font(.footnote)
            .foregroundStyle(TempoPalette.quiet)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 40)
        .frame(maxWidth: 980)
        .frame(maxWidth: .infinity)
      }
      .tempoScreen()
    }
    .task { systemSnapshot = .capture() }
    .fullScreenCover(isPresented: $showingOTARuntime) {
      TempoRuntimeScreen(route: .today)
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      Button { dismiss() } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.semibold))
          .frame(width: 42, height: 42)
          .background(TempoPalette.elevatedSurface, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("关闭开发者工具")

      VStack(alignment: .leading, spacing: 3) {
        Text("开发者工具")
          .font(.title2.weight(.semibold))
          .foregroundStyle(TempoPalette.ink)
        Text("OTA、同步与系统能力诊断")
          .font(.caption)
          .foregroundStyle(TempoPalette.quiet)
      }

      Spacer()

      Button {
        withAnimation(.snappy(duration: 0.32)) {
          selectedDetent = selectedDetent == .large ? .medium : .large
        }
      } label: {
        Image(systemName: selectedDetent == .large
          ? "arrow.down.right.and.arrow.up.left"
          : "arrow.up.left.and.arrow.down.right")
          .font(.body.weight(.semibold))
          .frame(width: 42, height: 42)
          .background(TempoPalette.elevatedSurface, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(selectedDetent == .large ? "缩小面板" : "全屏显示")
    }
  }

  private var otaCard: some View {
    DeveloperToolCard(
      title: "OTA 更新",
      subtitle: "仅更新 TypeScript 界面、样式和资源",
      symbol: "arrow.triangle.2.circlepath"
    ) {
      DeveloperMetricRow(title: "运行时版本", value: ota.runtimeVersion)
      DeveloperMetricRow(title: "更新通道", value: "production")
      DeveloperMetricRow(
        title: "原生容器",
        value: ota.isNativeRuntimeInstalled ? "已接入" : "尚未接入",
        valueColor: ota.isNativeRuntimeInstalled ? TempoPalette.success : TempoPalette.warning
      )
      DeveloperMetricRow(title: "云端状态", value: ota.state.title, valueColor: ota.state.color)

      if let detail = ota.detail {
        Text(detail)
          .font(.footnote)
          .foregroundStyle(TempoPalette.quiet)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 10) {
        Button { Task { await ota.check() } } label: {
          HStack(spacing: 8) {
            if ota.state == .checking { ProgressView().controlSize(.small) }
            Text("检查 OTA")
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(ota.state == .checking)

        Button {
          openURL(URL(string: "https://expo.dev/accounts/felixo1/projects/tempo-ios-runtime")!)
        } label: {
          Image(systemName: "arrow.up.right")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("打开 Expo 控制台")
      }

      Button {
        showingOTARuntime = true
      } label: {
        Label("打开 OTA 内容层", systemImage: "rectangle.on.rectangle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      if !ota.isNativeRuntimeInstalled {
        Label(
          "当前 IPA 只能检查云端兼容清单，不能下载并切换 OTA 包。首次接入 Expo 容器后，后续兼容更新才可免重装。",
          systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(TempoPalette.quiet)
      }
    }
  }

  private var syncCard: some View {
    let snapshot = store.developerSyncSnapshot
    return DeveloperToolCard(
      title: "同步诊断",
      subtitle: "查看实时连接与本机待上传状态",
      symbol: "arrow.left.arrow.right"
    ) {
      DeveloperMetricRow(title: "状态", value: snapshot.phase.title, valueColor: syncColor(snapshot.phase))
      DeveloperMetricRow(title: "服务", value: snapshot.serverConfigured ? "已配置" : "仅本地")
      DeveloperMetricRow(title: "Revision", value: String(snapshot.revision))
      DeveloperMetricRow(
        title: "待上传修改",
        value: String(snapshot.pendingChangeCount),
        valueColor: snapshot.pendingChangeCount == 0 ? TempoPalette.success : TempoPalette.warning
      )
      DeveloperMetricRow(title: "实时同步", value: snapshot.autoSyncEnabled ? "开启" : "关闭")

      if let syncMessage {
        Text(syncMessage)
          .font(.footnote)
          .foregroundStyle(syncMessage.contains("成功") ? TempoPalette.success : TempoPalette.danger)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Button { Task { await runSync() } } label: {
        HStack(spacing: 8) {
          if syncing { ProgressView().controlSize(.small) }
          Text("立即同步")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(syncing || !snapshot.serverConfigured)
    }
  }

  private var systemCard: some View {
    DeveloperToolCard(
      title: "系统能力",
      subtitle: "检查签名后最容易丢失的扩展和权限",
      symbol: "checkmark.shield"
    ) {
      DeveloperStatusRow(title: "Widget 扩展", available: systemSnapshot.widgetExtensionEmbedded)
      DeveloperStatusRow(
        title: "App Group 共享数据",
        available: systemSnapshot.appGroupAvailable,
        unavailableTitle: "签名未授权"
      )
      DeveloperStatusRow(title: "灵动岛与实时活动", available: systemSnapshot.liveActivitiesEnabled)

      if !systemSnapshot.appGroupAvailable {
        Label(
          "代码已声明 group.one.darker.qingxu；当前签名描述文件没有保留这项权限，主应用、小组件与灵动岛因此无法共享实时状态。",
          systemImage: "signature"
        )
        .font(.footnote)
        .foregroundStyle(TempoPalette.quiet)
      }

      Button {
        systemSnapshot = .capture()
      } label: {
        Label("重新检测", systemImage: "arrow.clockwise")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
  }

  private var appCard: some View {
    DeveloperToolCard(
      title: "运行信息",
      subtitle: "用于确认安装包、系统和构建来源",
      symbol: "hammer"
    ) {
      DeveloperMetricRow(title: "应用版本", value: "v\(updateChecker.currentVersion)")
      DeveloperMetricRow(title: "构建号", value: updateChecker.currentBuild)
      DeveloperMetricRow(title: "系统", value: "iOS \(UIDevice.current.systemVersion)")
      DeveloperMetricRow(title: "设备", value: UIDevice.current.model)
      DeveloperMetricRow(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "未知")
    }
  }

  private func columns(for width: CGFloat) -> [GridItem] {
    width >= 760
      ? [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
      : [GridItem(.flexible())]
  }

  @MainActor
  private func runSync() async {
    syncing = true
    syncMessage = nil
    let succeeded = await store.syncNow()
    syncMessage = succeeded ? "同步成功，本机与服务器状态已刷新。" : "同步失败，请查看状态或检查网络。"
    syncing = false
  }

  private func syncColor(_ phase: SyncPhase) -> Color {
    switch phase {
    case .synced: TempoPalette.success
    case .syncing: TempoPalette.accent
    case .failed: TempoPalette.danger
    case .localOnly: TempoPalette.quiet
    }
  }

  private var diagnosticReport: String {
    let sync = store.developerSyncSnapshot
    return """
    Tempo 脱敏诊断
    生成时间：\(Date().formatted(date: .numeric, time: .standard))

    应用：v\(updateChecker.currentVersion) (\(updateChecker.currentBuild))
    Bundle：\(Bundle.main.bundleIdentifier ?? "未知")
    系统：iOS \(UIDevice.current.systemVersion)
    设备：\(UIDevice.current.model)

    OTA 运行时：\(ota.runtimeVersion)
    OTA 容器：\(ota.isNativeRuntimeInstalled ? "已接入" : "尚未接入")
    OTA 检查：\(ota.state.title)

    同步状态：\(sync.phase.title)
    Revision：\(sync.revision)
    待上传修改：\(sync.pendingChangeCount)
    自动同步：\(sync.autoSyncEnabled ? "开启" : "关闭")
    服务器：\(sync.serverConfigured ? "已配置" : "未配置")

    Widget 扩展：\(systemSnapshot.widgetExtensionEmbedded ? "存在" : "缺失")
    App Group：\(systemSnapshot.appGroupAvailable ? "可用" : "不可用")
    实时活动：\(systemSnapshot.liveActivitiesEnabled ? "允许" : "不可用")

    注：报告不包含服务器地址、同步密钥或任何 API 密钥。
    """
  }
}

private struct DeveloperToolCard<Content: View>: View {
  let title: String
  let subtitle: String
  let symbol: String
  let content: Content

  init(title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.symbol = symbol
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        Image(systemName: symbol)
          .font(.body.weight(.semibold))
          .frame(width: 36, height: 36)
          .background(TempoPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.headline)
          Text(subtitle).font(.caption).foregroundStyle(TempoPalette.quiet)
        }
      }

      Divider()
      content
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TempoPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(TempoPalette.separator.opacity(0.45), lineWidth: 0.5)
    }
  }
}

private struct DeveloperMetricRow: View {
  let title: String
  let value: String
  var valueColor = TempoPalette.quiet

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title).foregroundStyle(TempoPalette.ink)
      Spacer(minLength: 12)
      Text(value)
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(valueColor)
        .multilineTextAlignment(.trailing)
        .textSelection(.enabled)
    }
  }
}

private struct DeveloperStatusRow: View {
  let title: String
  let available: Bool
  var unavailableTitle = "不可用"

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
      Spacer()
      Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(available ? TempoPalette.success : TempoPalette.danger)
      Text(available ? "可用" : unavailableTitle)
        .font(.subheadline)
        .foregroundStyle(TempoPalette.quiet)
    }
  }
}

@MainActor
private final class TempoOTAInspector: ObservableObject {
  enum State: Equatable {
    case idle
    case checking
    case reachable
    case noUpdate
    case failed

    var title: String {
      switch self {
      case .idle: "尚未检查"
      case .checking: "正在检查"
      case .reachable: "兼容清单可用"
      case .noUpdate: "暂无兼容更新"
      case .failed: "检查失败"
      }
    }

    var color: Color {
      switch self {
      case .reachable: TempoPalette.success
      case .failed: TempoPalette.danger
      case .checking: TempoPalette.accent
      case .idle, .noUpdate: TempoPalette.quiet
      }
    }
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var detail: String?

  let runtimeVersion: String
  let isNativeRuntimeInstalled: Bool
  private let endpoint = URL(string: "https://u.expo.dev/3f6ada73-f58c-47e5-b146-935f18f8ba4c")!

  init(bundle: Bundle = .main) {
    runtimeVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    _ = ReactNativeHostManager.shared
    isNativeRuntimeInstalled = true
  }

  func check() async {
    state = .checking
    detail = nil
    do {
      var request = URLRequest(url: endpoint)
      request.timeoutInterval = 15
      request.setValue("1", forHTTPHeaderField: "expo-protocol-version")
      request.setValue("ios", forHTTPHeaderField: "expo-platform")
      request.setValue(runtimeVersion, forHTTPHeaderField: "expo-runtime-version")
      request.setValue("production", forHTTPHeaderField: "expo-channel-name")
      request.setValue("Tempo-iOS/\(runtimeVersion)", forHTTPHeaderField: "User-Agent")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw OTAInspectionError.invalidResponse }
      switch http.statusCode {
      case 200..<300 where http.statusCode != 204:
        state = .reachable
        detail = updateIdentifier(in: data).map { "云端更新 ID：\($0)" }
          ?? "EAS 已返回与当前运行时兼容的更新清单。"
      case 204, 404:
        state = .noUpdate
        detail = "production 通道还没有与 v\(runtimeVersion) 兼容的更新。"
      default:
        throw OTAInspectionError.httpStatus(http.statusCode)
      }
    } catch {
      state = .failed
      detail = error.localizedDescription
    }
  }

  private func updateIdentifier(in data: Data) -> String? {
    guard let text = String(data: data, encoding: .utf8),
          let range = text.range(of: #"\"id\"\s*:\s*\"([^\"]+)\""#, options: .regularExpression)
    else { return nil }
    let match = String(text[range])
    return match
      .split(separator: "\"")
      .dropFirst()
      .dropFirst()
      .first
      .map(String.init)
  }
}

private enum OTAInspectionError: LocalizedError {
  case invalidResponse
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .invalidResponse: "OTA 服务没有返回有效响应。"
    case .httpStatus(let status): "OTA 服务响应异常（HTTP \(status)）。"
    }
  }
}

private struct TempoSystemDiagnosticSnapshot {
  let widgetExtensionEmbedded: Bool
  let appGroupAvailable: Bool
  let liveActivitiesEnabled: Bool

  static func capture() -> Self {
    let widgetEmbedded = Bundle.main.builtInPlugInsURL
      .flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
      .map { bundles in bundles.contains { $0.pathExtension == "appex" } }
      ?? false
    let appGroupAvailable = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.one.darker.qingxu"
    ) != nil
    return Self(
      widgetExtensionEmbedded: widgetEmbedded,
      appGroupAvailable: appGroupAvailable,
      liveActivitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled
    )
  }
}
