import 'package:hive_flutter/hive_flutter.dart';

/// Centralized persistence layer using Hive
class PersistenceService {
  static late Box _toolsBox;
  static late Box _appBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _toolsBox = await Hive.openBox('tools_data');
    _appBox = await Hive.openBox('app_data');
  }

  // ═══ Tools Data ═══

  // Water cups
  static int getWaterCups() =>
      _toolsBox.get('water_cups_${_todayKey()}', defaultValue: 0);
  static Future<void> setWaterCups(int cups) =>
      _toolsBox.put('water_cups_${_todayKey()}', cups);

  // Mood entries
  static List<Map<String, dynamic>> getMoodEntries() {
    final raw = _toolsBox.get('mood_entries', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> setMoodEntries(List<Map<String, dynamic>> entries) =>
      _toolsBox.put('mood_entries', entries);

  // Recordings
  static List<Map<String, String>> getRecordings() {
    final raw = _toolsBox.get('recordings', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  static Future<void> setRecordings(List<Map<String, String>> recordings) =>
      _toolsBox.put('recordings', recordings);

  // ═══ App Data (Goals, Habits, Events, Pomodoro) ═══

  // Pomodoro count & focus minutes (daily)
  static int getPomodoroCount() =>
      _appBox.get('pomo_count_${_todayKey()}', defaultValue: 0);
  static Future<void> setPomodoroCount(int count) =>
      _appBox.put('pomo_count_${_todayKey()}', count);
  static int getFocusMinutes() =>
      _appBox.get('focus_minutes_${_todayKey()}', defaultValue: 0);
  static Future<void> setFocusMinutes(int minutes) =>
      _appBox.put('focus_minutes_${_todayKey()}', minutes);

  // Goals
  static List<Map<String, dynamic>> getGoals() {
    final raw = _appBox.get('goals', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> setGoals(List<Map<String, dynamic>> goals) =>
      _appBox.put('goals', goals);

  // Habits
  static List<Map<String, dynamic>> getHabits() {
    final raw = _appBox.get('habits', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> setHabits(List<Map<String, dynamic>> habits) =>
      _appBox.put('habits', habits);

  // Habit completion dates (track which days were completed)
  static List<String> getHabitCompletionDates(String habitId) {
    final raw = _appBox.get('habit_dates_$habitId', defaultValue: <dynamic>[]);
    return (raw as List).cast<String>();
  }

  static Future<void> setHabitCompletionDates(
    String habitId,
    List<String> dates,
  ) => _appBox.put('habit_dates_$habitId', dates);

  // Events per date
  static List<Map<String, dynamic>> getEvents(String dateKey) {
    final raw = _appBox.get('events_$dateKey', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> setEvents(
    String dateKey,
    List<Map<String, dynamic>> events,
  ) => _appBox.put('events_$dateKey', events);

  // Daily focus stats (for heatmap — stores pomodoro count per day)
  static Map<String, int> getDailyFocusStats() {
    final result = <String, int>{};
    for (final key in _appBox.keys) {
      final k = key.toString();
      if (k.startsWith('pomo_count_')) {
        final dateKey = k.substring(11); // remove "pomo_count_"
        final count = _appBox.get(k, defaultValue: 0) as int;
        if (count > 0) result[dateKey] = count;
      }
    }
    return result;
  }

  /// Record a pomodoro for today (increment daily counter for heatmap)
  static Future<void> recordDailyPomodoro() async {
    final key = 'pomo_count_${_todayKey()}';
    final current = _appBox.get(key, defaultValue: 0) as int;
    await _appBox.put(key, current + 1);
  }

  // Weekly productivity data
  static List<double> getWeeklyProductivity() {
    final raw = _appBox.get(
      'weekly_productivity',
      defaultValue: <dynamic>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    );
    return (raw as List).cast<double>();
  }

  static Future<void> setWeeklyProductivity(List<double> data) =>
      _appBox.put('weekly_productivity', data);

  // Settings
  static String getThemeMode() =>
      _appBox.get('theme_mode', defaultValue: '\u8ddf\u968f\u7cfb\u7edf');
  static Future<void> setThemeMode(String mode) =>
      _appBox.put('theme_mode', mode);
  static String getUiStyle() => _appBox.get('ui_style', defaultValue: 'Miuix');
  static Future<void> setUiStyle(String style) =>
      _appBox.put('ui_style', style);
  static bool getLiquidGlass() =>
      _appBox.get('liquid_glass', defaultValue: true);
  static Future<void> setLiquidGlass(bool v) => _appBox.put('liquid_glass', v);
  static bool getBlurEffect() => _appBox.get('blur_effect', defaultValue: true);
  static Future<void> setBlurEffect(bool v) => _appBox.put('blur_effect', v);
  static bool getFloatingBar() =>
      _appBox.get('floating_bar', defaultValue: true);
  static Future<void> setFloatingBar(bool v) => _appBox.put('floating_bar', v);
  static bool getPredictiveBack() =>
      _appBox.get('predictive_back', defaultValue: true);
  static Future<void> setPredictiveBack(bool v) =>
      _appBox.put('predictive_back', v);
  static int getPomoDuration() =>
      _appBox.get('pomo_duration', defaultValue: 25);
  static Future<void> setPomoDuration(int v) => _appBox.put('pomo_duration', v);

  // Privacy consent
  static bool getPrivacyAgreed() =>
      _appBox.get('privacy_agreed', defaultValue: false);
  static Future<void> setPrivacyAgreed(bool v) =>
      _appBox.put('privacy_agreed', v);

  // ═══ Cloud Sync Helpers ═══

  /// Get all event date keys stored in Hive
  static List<String> getAllEventDateKeys() {
    final keys = <String>[];
    for (final key in _appBox.keys) {
      final k = key.toString();
      if (k.startsWith('events_')) {
        keys.add(k.substring(7)); // remove "events_" prefix
      }
    }
    return keys;
  }

  /// Clear all events from local storage
  static void clearAllEvents() {
    final keysToDelete = <dynamic>[];
    for (final key in _appBox.keys) {
      if (key.toString().startsWith('events_')) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      _appBox.delete(key);
    }
  }

  /// Get all daily stat date keys
  static List<String> getAllDailyStatKeys() {
    final keys = <String>{};
    for (final key in _appBox.keys) {
      final k = key.toString();
      if (k.startsWith('pomo_count_')) {
        keys.add(k.substring(11));
      } else if (k.startsWith('focus_minutes_')) {
        keys.add(k.substring(14));
      }
    }
    for (final key in _toolsBox.keys) {
      final k = key.toString();
      if (k.startsWith('water_cups_')) {
        keys.add(k.substring(11));
      }
    }
    return keys.toList();
  }

  /// Get pomodoro count for a specific date
  static int getPomodoroCountForDate(String dateKey) =>
      _appBox.get('pomo_count_$dateKey', defaultValue: 0);

  /// Get focus minutes for a specific date
  static int getFocusMinutesForDate(String dateKey) =>
      _appBox.get('focus_minutes_$dateKey', defaultValue: 0);

  /// Get water cups for a specific date
  static int getWaterCupsForDate(String dateKey) =>
      _toolsBox.get('water_cups_$dateKey', defaultValue: 0);

  /// Set daily stats for a specific date (from cloud sync)
  static Future<void> setDailyStats(
    String dateKey, {
    required int pomoCount,
    required int focusMinutes,
    required int waterCups,
  }) async {
    await _appBox.put('pomo_count_$dateKey', pomoCount);
    await _appBox.put('focus_minutes_$dateKey', focusMinutes);
    await _toolsBox.put('water_cups_$dateKey', waterCups);
  }

  /// Get current week key (e.g., "2026-15" for week 15 of 2026)
  static String currentWeekKey() {
    final now = DateTime.now();
    final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7)
        .ceil();
    return '${now.year}-$weekNumber';
  }

  // ═══ Clear all user data (on logout / account switch) ═══
  /// Clears ALL user-specific data while preserving app settings (theme, UI).
  /// Call this when logging out to prevent data leaking between accounts.
  /// OPT-9: Use batch deleteAll for performance
  static Future<void> clearAllUserData() async {
    // Collect keys to delete from _appBox (keep settings)
    final settingsKeys = {
      'theme_mode', 'ui_style', 'liquid_glass', 'blur_effect',
      'floating_bar', 'predictive_back', 'pomo_duration',
      'privacy_agreed', // Preserve privacy consent across logout/account switch
    };
    final appKeysToDelete = _appBox.keys
        .where((key) => !settingsKeys.contains(key.toString()))
        .toList();
    // OPT-9: batch delete instead of one-by-one
    await _appBox.deleteAll(appKeysToDelete);

    // Clear all tools data (mood, water, recordings)
    final toolsKeysToDelete = _toolsBox.keys.toList();
    await _toolsBox.deleteAll(toolsKeysToDelete);
  }

  /// BUG-18: Compact Hive boxes to reclaim disk space
  static Future<void> compactBoxes() async {
    await _toolsBox.compact();
    await _appBox.compact();
  }

  // ═══ Helpers ═══
  /// Unified date key format: YYYY-M-D (no zero-padding)
  /// CRITICAL: All dateKey usages across the app MUST use this format.
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Public helper for other services to generate consistent date keys.
  static String dateKeyFor(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
