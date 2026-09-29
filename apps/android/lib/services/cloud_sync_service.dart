import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';
import 'persistence_service.dart';

/// Cloud sync service — push local data to server, pull from server
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._();
  factory CloudSyncService() => _instance;
  CloudSyncService._();

  /// Reuse a single HTTP client for connection pooling (BUG-9 fix)
  final http.Client _client = http.Client();

  bool _syncing = false;
  bool get isSyncing => _syncing;
  String? _lastSyncTime;
  String? get lastSyncTime => _lastSyncTime;

  /// OPT-3: Throttle auto-sync — at least 30s between pushes
  int _lastPushMs = 0;
  static const int _minSyncIntervalMs = 30000; // 30 seconds

  /// Push all local data to cloud
  Future<({bool success, String? error})> pushToCloud() async {
    if (_syncing) return (success: false, error: '正在同步中');
    final auth = AuthService();
    if (!auth.isLoggedIn) return (success: false, error: '未登录');

    _syncing = true;
    try {
      final payload = await _collectLocalData();

      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/sync/push'),
            headers: auth.authHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        _lastSyncTime = data['synced_at'] as String?;
        _lastPushMs = DateTime.now().millisecondsSinceEpoch;
        _syncing = false;
        return (success: true, error: null);
      }
      _syncing = false;
      return (success: false, error: (data['error'] as String?) ?? '同步失败');
    } catch (e) {
      _syncing = false;
      if (kDebugMode) debugPrint('Push sync error: $e');
      return (success: false, error: '网络错误');
    }
  }

  /// Pull all cloud data and overwrite local
  /// BUG-11 fix: apply data safely — only clear old data after successful parse
  Future<({bool success, String? error})> pullFromCloud() async {
    if (_syncing) return (success: false, error: '正在同步中');
    final auth = AuthService();
    if (!auth.isLoggedIn) return (success: false, error: '未登录');

    _syncing = true;
    try {
      final resp = await _client
          .get(
            Uri.parse('${ServerConfig.baseUrl}/api/sync/pull'),
            headers: auth.authHeaders,
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        final cloudData = data['data'] as Map<String, dynamic>;

        // BUG-11 fix: Parse ALL cloud data first before clearing local.
        // If parsing fails, local data is preserved.
        final parsedData = _parseCloudData(cloudData);

        // Only clear + write after successful parse
        await PersistenceService.clearAllUserData();
        await _writeCloudData(parsedData);

        _lastSyncTime = cloudData['last_sync'] as String?;
        _syncing = false;
        return (success: true, error: null);
      }
      _syncing = false;
      return (success: false, error: (data['error'] as String?) ?? '拉取失败');
    } catch (e) {
      _syncing = false;
      if (kDebugMode) debugPrint('Pull sync error: $e');
      return (success: false, error: '网络错误');
    }
  }

  /// Get cloud sync status
  Future<Map<String, dynamic>?> getStatus() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return null;
    try {
      final resp = await _client
          .get(
            Uri.parse('${ServerConfig.baseUrl}/api/sync/status'),
            headers: auth.authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        _lastSyncTime = data['last_sync'] as String?;
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Auto sync: push local data when user is logged in (called after data changes)
  /// BUG-10 fix: catch errors to prevent unhandled exceptions
  /// OPT-3: Throttle to at least 30s between pushes
  Future<void> autoSync() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || _syncing) return;

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
