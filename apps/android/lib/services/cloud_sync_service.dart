import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'persistence_service.dart';

/// Cloud sync service — push local data to server, pull from server
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._();
  factory CloudSyncService() => _instance;
  CloudSyncService._();

  /// Reuse a single HTTP client for connection pooling (BUG-9 fix)
  final http.Client _client = http.Client();
  static const _secureStorage = FlutterSecureStorage();
  static const _urlKey = 'tempo_sync_server_url';
  static const _tokenKey = 'tempo_sync_token';
  static const _lastSyncKey = 'tempo_sync_last_time';
  static const _dirtyKey = 'tempo_sync_local_dirty';
  static const _hasSyncedKey = 'tempo_sync_has_completed';

  String _serverUrl = '';
  String _token = '';
  String get serverUrl => _serverUrl;
  bool get isConfigured => _serverUrl.isNotEmpty && _token.length == 64;

  bool _syncing = false;
  bool get isSyncing => _syncing;
  String? _lastSyncTime;
  String? get lastSyncTime => _lastSyncTime;
  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;
  bool _hasCompletedSync = false;
  bool get hasCompletedSync => _hasCompletedSync;

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _serverUrl = preferences.getString(_urlKey) ?? '';
    _lastSyncTime = preferences.getString(_lastSyncKey);
    _hasPendingChanges = preferences.getBool(_dirtyKey) ?? false;
    _hasCompletedSync = preferences.getBool(_hasSyncedKey) ?? false;
    _token = await _secureStorage.read(key: _tokenKey) ?? '';
  }

  Future<void> markLocalDirty() async {
    _hasPendingChanges = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_dirtyKey, true);
  }

  Future<({bool success, String? error})> configure({
    required String serverUrl,
    required String token,
  }) async {
    final normalized = _normalizeServerUrl(serverUrl);
    if (normalized == null) {
      return (success: false, error: '请输入有效的 HTTPS 服务器地址');
    }
    final normalizedToken = token.trim();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalizedToken)) {
      return (success: false, error: '同步令牌必须是 64 位十六进制字符');
    }
    final oldURL = _serverUrl;
    final oldToken = _token;
    _serverUrl = normalized;
    _token = normalizedToken;
    final test = await testConnection();
    if (!test.success) {
      _serverUrl = oldURL;
      _token = oldToken;
      return test;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, _serverUrl);
    await _secureStorage.write(key: _tokenKey, value: _token);
    return (success: true, error: null);
  }

  Future<void> clearConfiguration() async {
    _serverUrl = '';
    _token = '';
    _lastSyncTime = null;
    _hasPendingChanges = false;
    _hasCompletedSync = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_urlKey);
    await preferences.remove(_lastSyncKey);
    await preferences.remove(_dirtyKey);
    await preferences.remove(_hasSyncedKey);
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<({bool success, String? error})> testConnection() async {
    if (!isConfigured) return (success: false, error: '请先配置自托管同步');
    try {
      final response = await _client
          .get(Uri.parse('$_serverUrl/v1/ping'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return (success: true, error: null);
      return (success: false, error: _responseError(response, '连接失败'));
    } catch (error) {
      if (kDebugMode) debugPrint('Sync connection error: $error');
      return (success: false, error: '无法连接同步服务器');
    }
  }

  /// OPT-3: Throttle auto-sync — at least 30s between pushes
  int _lastPushMs = 0;
  static const int _minSyncIntervalMs = 30000; // 30 seconds

  /// Push all local data to cloud
  Future<({bool success, String? error})> pushToCloud() async {
    if (_syncing) return (success: false, error: '正在同步中');
    if (!isConfigured) return (success: false, error: '请先配置自托管同步');

    _syncing = true;
    try {
      final payload = await _collectLocalData();
      final workspace = {
        'schema': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'data': payload,
      };

      final resp = await _client
          .post(
            Uri.parse('$_serverUrl/v1/sync'),
            headers: _headers,
            body: jsonEncode({
              'deviceId': 'android',
              'tasks': <dynamic>[],
              'workspace': workspace,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _lastSyncTime = data['serverTime'] as String?;
        await _markSyncCompleted();
        _lastPushMs = DateTime.now().millisecondsSinceEpoch;
        _syncing = false;
        return (success: true, error: null);
      }
      _syncing = false;
      return (success: false, error: _responseError(resp, '同步失败'));
    } catch (e) {
      _syncing = false;
      if (kDebugMode) debugPrint('Push sync error: $e');
      return (success: false, error: '网络错误');
    }
  }

  /// Pull the server snapshot without uploading a blank local document first.
  /// A local backup is restored if any write fails, so a partial response can
  /// never leave the device with an empty workspace.
  Future<({bool success, String? error})> pullFromCloud() async {
    if (_syncing) return (success: false, error: '正在同步中');
    if (!isConfigured) return (success: false, error: '请先配置自托管同步');

    _syncing = true;
    try {
      final resp = await _client
          .post(
            Uri.parse('$_serverUrl/v1/sync'),
            headers: _headers,
            body: jsonEncode({'deviceId': 'android', 'tasks': <dynamic>[]}),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final response = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawWorkspace = response['workspace'];
        if (rawWorkspace == null) {
          _syncing = false;
          return (success: false, error: '云端尚无 Android 数据，本机数据未改动');
        }
        final workspace = Map<String, dynamic>.from(rawWorkspace as Map);
        if (workspace['schema'] != 1 || workspace['data'] is! Map) {
          _syncing = false;
          return (success: false, error: '云端数据版本不兼容');
        }
        final cloudData = Map<String, dynamic>.from(workspace['data'] as Map);
        final parsedData = _parseCloudData(cloudData);
        final localBackup = _parseCloudData(await _collectLocalData());
        try {
          await PersistenceService.clearAllUserData();
          await _writeCloudData(parsedData);
        } catch (_) {
          await PersistenceService.clearAllUserData();
          await _writeCloudData(localBackup);
          rethrow;
        }

        _lastSyncTime = response['serverTime'] as String?;
        await _markSyncCompleted();
        _syncing = false;
        return (success: true, error: null);
      }
      _syncing = false;
      return (success: false, error: _responseError(resp, '拉取失败'));
    } catch (e) {
      _syncing = false;
      if (kDebugMode) debugPrint('Pull sync error: $e');
      return (success: false, error: '网络错误');
    }
  }

  /// Get cloud sync status
  Future<Map<String, dynamic>?> getStatus() async {
    if (!isConfigured) return null;
    try {
      final resp = await _client
          .get(
            Uri.parse('$_serverUrl/v1/ping'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) return {'status': 'ok'};
    } catch (_) {}
    return null;
  }

  /// Auto sync: push local data after self-hosted sync is configured.
  /// BUG-10 fix: catch errors to prevent unhandled exceptions
  /// OPT-3: Throttle to at least 30s between pushes
  Future<void> autoSync() async {
    if (!isConfigured || _syncing) return;

    // OPT-3: Throttle check
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPushMs < _minSyncIntervalMs) return;

    // BUG-10 fix: catch errors from fire-and-forget push
    pushToCloud().then(
      (_) {},
      onError: (e) {
        if (kDebugMode) debugPrint('Auto-sync error (suppressed): $e');
      },
    );
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  static String? _normalizeServerUrl(String value) {
    var candidate = value.trim();
    if (candidate.isEmpty) return null;
    if (!candidate.contains('://')) candidate = 'https://$candidate';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    final loopback = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
    if (uri.scheme != 'https' && !(loopback && uri.scheme == 'http')) {
      return null;
    }
    return candidate.replaceFirst(RegExp(r'/+$'), '');
  }

  String _responseError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (error is String) return error;
    } catch (_) {}
    if (response.statusCode == 401) return '同步令牌无效';
    return '$fallback（HTTP ${response.statusCode}）';
  }

  Future<void> _markSyncCompleted() async {
    _hasPendingChanges = false;
    _hasCompletedSync = true;
    final preferences = await SharedPreferences.getInstance();
    if (_lastSyncTime != null) {
      await preferences.setString(_lastSyncKey, _lastSyncTime!);
    }
    await preferences.setBool(_dirtyKey, false);
    await preferences.setBool(_hasSyncedKey, true);
  }

  // ═══ Parse cloud data into safe typed structures (BUG-11) ═══
  _CloudPayload _parseCloudData(Map<String, dynamic> cloud) {
    // Events
    final events = <String, List<Map<String, dynamic>>>{};
    if (cloud['events'] != null) {
      final raw = cloud['events'] as Map<String, dynamic>;
      for (final entry in raw.entries) {
        events[entry.key] = (entry.value as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    // Goals
    final goals = <Map<String, dynamic>>[];
    if (cloud['goals'] != null) {
      goals.addAll(
        (cloud['goals'] as List).map(
          (g) => Map<String, dynamic>.from(g as Map),
        ),
      );
    }

    // Habits with completion dates
    final habits = <Map<String, dynamic>>[];
    final habitDates = <String, List<String>>{};
    if (cloud['habits'] != null) {
      for (final h in (cloud['habits'] as List)) {
        final hm = Map<String, dynamic>.from(h as Map);
        final dates =
            (hm.remove('completion_dates') as List?)
                ?.map((d) => d.toString())
                .toList() ??
            [];
        final id = hm['id'] as String? ?? '';
        habits.add(hm);
        habitDates[id] = dates;
      }
    }

    // Daily stats
    final dailyStats = <String, Map<String, dynamic>>{};
    if (cloud['daily_stats'] != null) {
      final daily = cloud['daily_stats'] as Map<String, dynamic>;
      for (final entry in daily.entries) {
        dailyStats[entry.key] = Map<String, dynamic>.from(entry.value as Map);
      }
    }

    // Mood entries
    final moods = <Map<String, dynamic>>[];
    if (cloud['mood_entries'] != null) {
      moods.addAll(
        (cloud['mood_entries'] as List).map(
          (m) => Map<String, dynamic>.from(m as Map),
        ),
      );
    }

    // Weekly productivity
    final weeklyProd = <String, List<double>>{};
    if (cloud['weekly_productivity'] != null) {
      final weekly = cloud['weekly_productivity'] as Map<String, dynamic>;
      for (final entry in weekly.entries) {
        weeklyProd[entry.key] = (entry.value as List)
            .map((v) => (v as num).toDouble())
            .toList();
      }
    }

    return _CloudPayload(
      events: events,
      goals: goals,
      habits: habits,
      habitDates: habitDates,
      dailyStats: dailyStats,
      moods: moods,
      weeklyProd: weeklyProd,
    );
  }

  /// Write pre-parsed cloud data to local storage
  Future<void> _writeCloudData(_CloudPayload p) async {
    for (final entry in p.events.entries) {
      await PersistenceService.setEvents(entry.key, entry.value);
    }
    await PersistenceService.setGoals(p.goals);
    await PersistenceService.setHabits(p.habits);
    for (final entry in p.habitDates.entries) {
      await PersistenceService.setHabitCompletionDates(entry.key, entry.value);
    }
    for (final entry in p.dailyStats.entries) {
      final stats = entry.value;
      await PersistenceService.setDailyStats(
        entry.key,
        pomoCount: stats['pomo_count'] as int? ?? 0,
        focusMinutes: stats['focus_minutes'] as int? ?? 0,
        waterCups: stats['water_cups'] as int? ?? 0,
      );
    }
    await PersistenceService.setMoodEntries(p.moods);
    for (final entry in p.weeklyProd.entries) {
      await PersistenceService.setWeeklyProductivity(entry.value);
    }
  }

  // ═══ Collect all local data into sync payload ═══
  Future<Map<String, dynamic>> _collectLocalData() async {
    final payload = <String, dynamic>{};

    // Events: collect all date keys from Hive
    final events = <String, List<Map<String, dynamic>>>{};
    final allEventKeys = PersistenceService.getAllEventDateKeys();
    for (final dateKey in allEventKeys) {
      final evts = PersistenceService.getEvents(dateKey);
      if (evts.isNotEmpty) events[dateKey] = evts;
    }
    payload['events'] = events;

    // Goals
    payload['goals'] = PersistenceService.getGoals();

    // Habits (with completion dates)
    final habits = PersistenceService.getHabits();
    final habitsWithDates = habits.map((h) {
      final id = h['id'] as String? ?? '';
      final dates = PersistenceService.getHabitCompletionDates(id);
      return {...h, 'completion_dates': dates};
    }).toList();
    payload['habits'] = habitsWithDates;

    // Daily stats: collect all date keys
    final dailyStats = <String, Map<String, dynamic>>{};
    final dailyKeys = PersistenceService.getAllDailyStatKeys();
    for (final dateKey in dailyKeys) {
      dailyStats[dateKey] = {
        'pomo_count': PersistenceService.getPomodoroCountForDate(dateKey),
        'focus_minutes': PersistenceService.getFocusMinutesForDate(dateKey),
        'water_cups': PersistenceService.getWaterCupsForDate(dateKey),
      };
    }
    payload['daily_stats'] = dailyStats;

    // Mood entries
    payload['mood_entries'] = PersistenceService.getMoodEntries();

    // Weekly productivity
    final weeklyProd = <String, List<double>>{};
    final weekKey = PersistenceService.currentWeekKey();
    weeklyProd[weekKey] = PersistenceService.getWeeklyProductivity();
    payload['weekly_productivity'] = weeklyProd;

    return payload;
  }
}

/// Internal parsed cloud payload (BUG-11: parse-then-apply pattern)
class _CloudPayload {
  final Map<String, List<Map<String, dynamic>>> events;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> habits;
  final Map<String, List<String>> habitDates;
  final Map<String, Map<String, dynamic>> dailyStats;
  final List<Map<String, dynamic>> moods;
  final Map<String, List<double>> weeklyProd;

  _CloudPayload({
    required this.events,
    required this.goals,
    required this.habits,
    required this.habitDates,
    required this.dailyStats,
    required this.moods,
    required this.weeklyProd,
  });
}
