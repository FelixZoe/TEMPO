import Combine
import Foundation
import React
import UIKit

extension Notification.Name {
  static let tempoOpenDeveloperTools = Notification.Name("tempo.open-developer-tools")
}

@MainActor
final class TempoNativeRegistry {
  static let shared = TempoNativeRegistry()

  private weak var store: AppStore?
  private weak var rssStore: RSSStore?
  private weak var updateChecker: AppUpdateChecker?
  private var subscriptions = Set<AnyCancellable>()
  private var revision = 0
  private var pendingEmission: Task<Void, Never>?

  private init() {}

  func connect(store: AppStore, rssStore: RSSStore, updateChecker: AppUpdateChecker) {
    guard self.store !== store || self.rssStore !== rssStore || self.updateChecker !== updateChecker else {
      return
    }
    self.store = store
    self.rssStore = rssStore
    self.updateChecker = updateChecker
    subscriptions.removeAll()

    store.objectWillChange
      .sink { [weak self] _ in self?.scheduleEmission() }
      .store(in: &subscriptions)
    rssStore.objectWillChange
      .sink { [weak self] _ in self?.scheduleEmission() }
      .store(in: &subscriptions)
    updateChecker.objectWillChange
      .sink { [weak self] _ in self?.scheduleEmission() }
      .store(in: &subscriptions)
    emitSnapshot()
  }

  func snapshot() -> [String: Any] {
    let defaults = UserDefaults.standard
    let scheme = UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
    var result: [String: Any] = [
      "route": "today",
      "locale": Locale.current.identifier,
      "colorScheme": scheme,
      "revision": revision,
      "preferences": [
        "haptics": defaults.object(forKey: TempoPreferenceKey.haptics) as? Bool ?? true,
        "completionSound": defaults.object(forKey: TempoPreferenceKey.completionSound) as? Bool ?? true,
        "weekStartsMonday": defaults.object(forKey: TempoPreferenceKey.weekStartsMonday) as? Bool ?? true,
        "showFestivals": defaults.object(forKey: TempoPreferenceKey.showFestivals) as? Bool ?? true,
        "showTaskIndicators": defaults.object(forKey: TempoPreferenceKey.showTaskIndicators) as? Bool ?? true,
        "moduleOrder": defaults.string(forKey: TempoPreferenceKey.moduleOrder) ?? TempoModuleOrder.defaultValue,
      ],
      "ambient": ambientSnapshot(),
    ]

    if let store {
      result["tasks"] = jsonObject(store.tasks.filter { $0.deletedAt == nil })
      result["pomodoro"] = jsonObject(store.pomodoro)
      result["displayedRemainingSeconds"] = store.displayedRemainingSeconds
      let developer = store.developerSyncSnapshot
      result["sync"] = [
        "phase": developer.phase.title,
        "revision": developer.revision,
        "pendingChangeCount": developer.pendingChangeCount,
        "lastAutomaticSync": isoString(developer.lastAutomaticSync),
        "configured": developer.serverConfigured,
        "autoSync": developer.autoSyncEnabled,
        "serverURL": store.syncSettings.serverURL,
        "deviceName": store.syncSettings.deviceName,
        "hasToken": !store.syncSettings.token.isEmpty,
      ]
      result["ai"] = [
        "mode": store.aiSettings.mode.rawValue,
        "baseURL": store.aiSettings.baseURL,
        "model": store.aiSettings.model,
        "summaryPrompt": store.aiSettings.summaryPrompt,
        "configured": store.aiSettings.isConfigured(syncSettings: store.syncSettings),
        "hasAPIKey": !store.aiSettings.apiKey.isEmpty,
      ]
    } else {
      result["tasks"] = []
      result["displayedRemainingSeconds"] = 25 * 60
    }

    if let rssStore {
      result["rss"] = [
        "subscriptions": jsonObject(rssStore.subscriptions),
        "folders": jsonObject(rssStore.folders),
        "articles": rssStore.articles.prefix(300).map(articleSummary),
        "unreadCount": rssStore.unreadCount,
        "phase": rssPhase(rssStore.phase),
      ]
    } else {
      result["rss"] = ["subscriptions": [], "folders": [], "articles": [], "unreadCount": 0, "phase": "idle"]
    }

    if let updateChecker {
      result["app"] = [
        "version": updateChecker.currentVersion,
        "build": updateChecker.currentBuild,
        "update": updateState(updateChecker.state),
      ]
    }
    return result
  }

  func perform(action: String, payload: [String: Any]) async throws -> Any {
    guard let store else { throw BridgeError.notReady }
    switch action {
    case "task.add":
      let title = payload.string("title")
      let notes = payload.string("notes")
      let forToday = payload.bool("forToday")
      guard let task = store.addTask(title: title, notes: notes, forToday: forToday) else {
        throw BridgeError.invalidPayload("任务标题不能为空")
      }
      if let date = payload.date("scheduledAt") {
        var updated = task
        updated.startAt = Calendar.autoupdatingCurrent.startOfDay(for: date)
        store.updateTask(updated)
      }
      return ["ok": true]

    case "task.update":
      guard var task = task(payload.string("id"), in: store) else { throw BridgeError.notFound }
      if payload.keys.contains("title") { task.title = payload.string("title") }
      if payload.keys.contains("notes") { task.notes = payload.string("notes") }
      if payload.keys.contains("priority") {
        task.priority = TaskPriority(rawValue: payload.string("priority"))
      }
      if payload.keys.contains("scheduledAt") {
        task.startAt = payload.date("scheduledAt").map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
      }
      store.updateTask(task)
      return ["ok": true]

    case "task.toggle":
      guard let task = task(payload.string("id"), in: store) else { throw BridgeError.notFound }
      store.toggleTask(task)
      return ["ok": true]

    case "task.delete":
      guard let task = task(payload.string("id"), in: store) else { throw BridgeError.notFound }
      store.deleteTask(task)
      return ["ok": true]

    case "task.restore":
      guard let task = store.tasks.first(where: { $0.id == payload.string("id") }) else {
        throw BridgeError.notFound
      }
      store.restoreTask(task)
      return ["ok": true]

    case "pomodoro.toggle":
      store.togglePomodoro()
      return ["ok": true]
    case "pomodoro.reset":
      store.resetPomodoro()
      return ["ok": true]
    case "pomodoro.stop":
      store.stopPomodoro()
      return ["ok": true]
    case "pomodoro.mode":
      guard let mode = PomodoroMode(rawValue: payload.string("mode")) else {
        throw BridgeError.invalidPayload("计时模式无效")
      }
      store.setPomodoroMode(mode)
      return ["ok": true]
    case "pomodoro.direction":
      guard let direction = PomodoroTimerDirection(rawValue: payload.string("direction")) else {
        throw BridgeError.invalidPayload("计时方向无效")
      }
      store.setPomodoroTimerDirection(direction)
      return ["ok": true]
    case "pomodoro.settings":
      store.updateDurations(
        focus: payload.int("focus", fallback: store.pomodoro.focusMinutes),
        shortBreak: payload.int("shortBreak", fallback: store.pomodoro.shortBreakMinutes),
        longBreak: payload.int("longBreak", fallback: store.pomodoro.longBreakMinutes),
        longBreakEvery: payload.int("longBreakEvery", fallback: store.pomodoro.longBreakEvery),
        dailyFocusGoal: payload.int("dailyFocusGoal", fallback: store.pomodoro.dailyFocusGoal)
      )
      return ["ok": true]

    case "sync.now":
      return ["ok": await store.syncNow()]
    case "sync.save":
      var settings = store.syncSettings
      settings.serverURL = payload.string("serverURL")
      settings.deviceName = payload.string("deviceName")
      settings.autoSync = payload.bool("autoSync", fallback: true)
      let token = payload.string("token")
      if !token.isEmpty { settings.token = token }
      try store.saveSyncSettings(settings)
      return ["ok": true]
    case "sync.test":
      var settings = store.syncSettings
      settings.serverURL = payload.string("serverURL")
      settings.deviceName = payload.string("deviceName")
      let token = payload.string("token")
      if !token.isEmpty { settings.token = token }
      try await store.testConnection(settings)
      return ["ok": true]

    case "ai.save":
      var settings = store.aiSettings
      if let mode = AIConnectionMode(rawValue: payload.string("mode")) { settings.mode = mode }
      settings.baseURL = payload.string("baseURL")
      settings.model = payload.string("model")
      settings.summaryPrompt = payload.string("summaryPrompt")
      let key = payload.string("apiKey")
      if !key.isEmpty { settings.apiKey = key }
      try store.saveAISettings(settings)
      return ["ok": true]
    case "ai.test":
      try await store.testAIConnection(store.aiSettings)
      return ["ok": true]
    case "ai.plan":
      let plan = try await TempoAIClient().plan(
        goal: payload.string("goal"),
        tasks: store.tasks.filter { $0.deletedAt == nil },
        settings: store.syncSettings,
        aiSettings: store.aiSettings
      )
      return jsonObject(plan)

    case "rss.refresh":
      guard let rssStore else { throw BridgeError.notReady }
      await rssStore.refresh()
      return ["ok": true]
    case "rss.add":
      guard let rssStore else { throw BridgeError.notReady }
      try await rssStore.addSubscription(payload.string("url"))
      return ["ok": true]
    case "rss.toggleRead":
      guard let article = article(payload.string("id")) else { throw BridgeError.notFound }
      rssStore?.toggleRead(article)
      return ["ok": true]
    case "rss.toggleStar":
      guard let article = article(payload.string("id")) else { throw BridgeError.notFound }
      rssStore?.toggleStarred(article)
      return ["ok": true]
    case "rss.markAllRead":
      rssStore?.markAllRead(feedID: payload.optionalString("feedID"))
      return ["ok": true]
    case "rss.addFolder":
      rssStore?.createFolder(title: payload.string("title"))
      return ["ok": true]
    case "rss.deleteFeed":
      guard let feed = rssStore?.subscriptions.first(where: { $0.id == payload.string("id") }) else {
        throw BridgeError.notFound
      }
      rssStore?.delete(feed)
      return ["ok": true]
    case "rss.article":
      guard let article = article(payload.string("id")) else { throw BridgeError.notFound }
      rssStore?.markRead(article)
      return jsonObject(article)
    case "rss.summarize":
      guard let article = article(payload.string("id")) else { throw BridgeError.notFound }
      return try await TempoAIClient().summarize(
        title: article.title,
        content: article.content ?? article.summary,
        settings: store.syncSettings,
        aiSettings: store.aiSettings
      )
    case "rss.translate":
      let segments = payload["segments"] as? [String] ?? []
      return try await TempoAIClient().translate(
        segments: segments,
        settings: store.syncSettings,
        aiSettings: store.aiSettings
      )

    case "preferences.save":
      let defaults = UserDefaults.standard
      for key in ["haptics", "completionSound", "weekStartsMonday", "showFestivals", "showTaskIndicators"] {
        if let value = payload[key] as? Bool {
          defaults.set(value, forKey: preferenceKey(key))
        }
      }
      if let order = payload["moduleOrder"] as? String {
        defaults.set(order, forKey: TempoPreferenceKey.moduleOrder)
      }
      emitSnapshot()
      return ["ok": true]
    case "update.check":
      guard let updateChecker else { throw BridgeError.notReady }
      _ = await updateChecker.check(force: true)
      return updateState(updateChecker.state)
    case "update.download":
      guard let release = updateChecker?.availableRelease else { throw BridgeError.notFound }
      let url = release.iOSAsset?.browserDownloadURL ?? release.htmlURL
      await UIApplication.shared.open(url)
      return ["ok": true]
    case "developer.open":
      NotificationCenter.default.post(name: .tempoOpenDeveloperTools, object: nil)
      return ["ok": true]
    case "url.open":
      guard let url = URL(string: payload.string("url")) else {
        throw BridgeError.invalidPayload("链接无效")
      }
      await UIApplication.shared.open(url)
      return ["ok": true]
    default:
      throw BridgeError.invalidPayload("未知操作：\(action)")
    }
  }

  func sendCommand(_ type: String) {
    TempoNativeBridge.active?.sendCommand(["type": type])
  }

  private func task(_ id: String, in store: AppStore) -> TaskItem? {
    store.tasks.first { $0.id == id && $0.deletedAt == nil }
  }

  private func article(_ id: String) -> RSSArticle? {
    rssStore?.articles.first { $0.id == id }
  }

  private func scheduleEmission() {
    pendingEmission?.cancel()
    pendingEmission = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(24))
      guard !Task.isCancelled else { return }
      self?.emitSnapshot()
    }
  }

  private func emitSnapshot() {
    revision += 1
    TempoNativeBridge.active?.sendSnapshot(snapshot())
  }

  private func ambientSnapshot() -> [String: Any] {
    var value: [String: Any] = [:]
    if let data = UserDefaults.standard.data(forKey: "qingxu.ambient.quote-cache.v1"),
       let quote = try? JSONDecoder().decode(TempoQuoteSnapshot.self, from: data) {
      value["quote"] = jsonObject(quote)
    }
    if let data = UserDefaults.standard.data(forKey: "qingxu.ambient.weather-cache.v1"),
       let weather = try? JSONDecoder().decode(TempoWeatherSnapshot.self, from: data) {
      value["weather"] = jsonObject(weather)
    }
    return value
  }

  private func articleSummary(_ article: RSSArticle) -> [String: Any] {
    [
      "id": article.id,
      "feedID": article.feedID,
      "feedTitle": article.feedTitle,
      "title": article.title,
      "summary": article.summary,
      "link": article.link,
      "author": article.author ?? NSNull(),
      "publishedAt": article.publishedAt.map(isoString) ?? NSNull(),
      "fetchedAt": isoString(article.fetchedAt),
      "isRead": article.isRead,
      "isStarred": article.isStarred,
      "readingProgress": article.readingProgress ?? 0,
    ]
  }

  private func rssPhase(_ phase: RSSStorePhase) -> String {
    switch phase {
    case .idle: "idle"
    case .refreshing: "refreshing"
    case .failed(let message): "failed:\(message)"
    }
  }

  private func updateState(_ state: AppUpdateChecker.State) -> [String: Any] {
    switch state {
    case .idle: return ["state": "idle"]
    case .checking: return ["state": "checking"]
    case .current: return ["state": "current"]
    case .failed(let message): return ["state": "failed", "message": message]
    case .available(let release):
      return [
        "state": "available",
        "version": release.version,
        "notes": release.body,
        "downloadURL": (release.iOSAsset?.browserDownloadURL ?? release.htmlURL).absoluteString,
      ]
    }
  }

  private func preferenceKey(_ name: String) -> String {
    switch name {
    case "haptics": TempoPreferenceKey.haptics
    case "completionSound": TempoPreferenceKey.completionSound
    case "weekStartsMonday": TempoPreferenceKey.weekStartsMonday
    case "showFestivals": TempoPreferenceKey.showFestivals
    default: TempoPreferenceKey.showTaskIndicators
    }
  }
}

@objc(TempoNativeBridge)
final class TempoNativeBridge: RCTEventEmitter {
  fileprivate static weak var active: TempoNativeBridge?
  private var observing = false

  override init() {
    super.init()
    Self.active = self
  }

  @objc override static func requiresMainQueueSetup() -> Bool { true }
  override func supportedEvents() -> [String]! { ["tempoStateDidChange", "tempoCommand"] }
  override func startObserving() { observing = true }
  override func stopObserving() { observing = false }

  @objc(bootstrap:rejecter:)
  func bootstrap(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    Task { @MainActor in resolve(TempoNativeRegistry.shared.snapshot()) }
  }

  @objc(perform:payload:resolver:rejecter:)
  func perform(
    _ action: String,
    payload: [String: Any],
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    Task { @MainActor in
      do {
        resolve(try await TempoNativeRegistry.shared.perform(action: action, payload: payload))
      } catch {
        reject("tempo_native_error", error.localizedDescription, error)
      }
    }
  }

  fileprivate func sendSnapshot(_ snapshot: [String: Any]) {
    guard observing else { return }
    sendEvent(withName: "tempoStateDidChange", body: snapshot)
  }

  fileprivate func sendCommand(_ command: [String: Any]) {
    guard observing else { return }
    sendEvent(withName: "tempoCommand", body: command)
  }
}

private enum BridgeError: LocalizedError {
  case notReady
  case notFound
  case invalidPayload(String)

  var errorDescription: String? {
    switch self {
    case .notReady: "Tempo 数据层尚未准备好"
    case .notFound: "没有找到对应的数据"
    case .invalidPayload(let message): message
    }
  }
}

private func jsonObject<T: Encodable>(_ value: T) -> Any {
  guard let data = try? TempoCoding.encoder.encode(value),
        let object = try? JSONSerialization.jsonObject(with: data)
  else { return NSNull() }
  return object
}

private func isoString(_ date: Date) -> String { date.ISO8601Format() }

private let bridgeDateFormatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

private extension Dictionary where Key == String, Value == Any {
  func string(_ key: String) -> String { self[key] as? String ?? "" }
  func optionalString(_ key: String) -> String? {
    let value = string(key).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
  func bool(_ key: String, fallback: Bool = false) -> Bool { self[key] as? Bool ?? fallback }
  func int(_ key: String, fallback: Int) -> Int { (self[key] as? NSNumber)?.intValue ?? fallback }
  func date(_ key: String) -> Date? {
    guard let value = self[key] as? String, !value.isEmpty else { return nil }
    return bridgeDateFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
}
