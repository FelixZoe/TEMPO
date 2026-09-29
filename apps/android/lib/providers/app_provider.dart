import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/persistence_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/auth_service.dart';

class AppProvider extends ChangeNotifier {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();

  // ═══ Cloud sync (debounced) ═══
  bool _syncPending = false;
  void _scheduleSync() {
    if (_syncPending) return;
    _syncPending = true;
    Future.delayed(const Duration(seconds: 5), () {
      _syncPending = false;
      // OPT-3: CloudSyncService.autoSync() now has internal throttle + error catch
      CloudSyncService().autoSync();
    });
  }

  /// Pull cloud data and reload provider state
  Future<bool> pullAndReload() async {
    final result = await CloudSyncService().pullFromCloud();
    if (result.success) {
      _clearInMemoryUserData(); // Clear stale in-memory caches before reloading
      await _loadPersistedData();
      notifyListeners();
    }
    return result.success;
  }

  /// Clear all in-memory user data caches.
  /// Prevents cross-account data leaking when switching users.
  void _clearInMemoryUserData() {
    _allEvents.clear();
    _habits.clear();
    _goals.clear();
    _pomodoroCount = 0;
    _focusMinutes = 0;
  }

  /// Public version: called from settings page after logout
  void clearUserDataAndReload() {
    _clearInMemoryUserData();
    notifyListeners();
  }

  // ═══ 使用天数（从注册日期算起，登录后才计数）═══
  int get usageDays {
    final user = AuthService().currentUser;
    if (user == null || user.createdAt.isEmpty) return 0;
    final registerDate = DateTime.tryParse(user.createdAt);
    if (registerDate == null) return 0;
    return DateTime.now().difference(registerDate).inDays;
  }

  /// 初始化：加载持久化数据，若已登录则自动从云端拉取
  Future<void> initUsageTracking() async {
    _clearInMemoryUserData(); // Start clean
    await _loadPersistedData();
    notifyListeners(); // Single rebuild with all local data ready

    // Batch background tasks: cache size + cloud pull run in parallel
    // Each calls notifyListeners() only when it has new data.
    final futures = <Future>[calculateCacheSize()];
    if (AuthService().isLoggedIn) {
      futures.add(pullAndReload());
    }
    // Don't await — these complete in background and each triggers
    // its own targeted notifyListeners() call.
    Future.wait(futures);
  }

  Future<void> _loadPersistedData() async {
    // Load pomodoro
    _pomodoroCount = PersistenceService.getPomodoroCount();
    _focusMinutes = PersistenceService.getFocusMinutes();

    // Load settings
    _themeMode = PersistenceService.getThemeMode();
    _uiStyle = PersistenceService.getUiStyle();
    _liquidGlass = PersistenceService.getLiquidGlass();
    _blurEffect = PersistenceService.getBlurEffect();
    _floatingBar = PersistenceService.getFloatingBar();
    _predictiveBack = PersistenceService.getPredictiveBack();
    _pomoDuration = PersistenceService.getPomoDuration();

    // Load goals
    final goalMaps = PersistenceService.getGoals();
    _goals.clear();
    for (final g in goalMaps) {
      _goals.add(
        GoalItem(
          id: g['id'] as String? ?? '',
          title: g['title'] as String? ?? '',
          icon: g['icon'] as String? ?? 'flag',
          progress: (g['progress'] as num?)?.toDouble() ?? 0.0,
          color: Color(g['color'] as int? ?? 0xFF007AFF),
          target: g['target'] as String? ?? '',
        ),
      );
    }

    // Load habits
    final habitMaps = PersistenceService.getHabits();
    _habits.clear();
    final todayKey = _todayKeyStr();
    for (final h in habitMaps) {
      final dates = PersistenceService.getHabitCompletionDates(
        h['id'] as String? ?? '',
      );
      _habits.add(
        HabitItem(
          id: h['id'] as String? ?? '',
          title: h['title'] as String? ?? '',
          icon: h['icon'] as String? ?? 'circle',
          streak: (h['streak'] as int?) ?? 0,
          color: Color(h['color'] as int? ?? 0xFF007AFF),
          todayCompleted: dates.contains(todayKey),
        ),
      );
    }

    // Load events for today
    final dateKey = _dateKey(_selectedDate);
    final eventMaps = PersistenceService.getEvents(dateKey);
    _allEvents[dateKey] = eventMaps
        .map(
          (e) => ScheduleEvent(
            id: e['id'] as String? ?? '',
            title: e['title'] as String? ?? '',
            description: e['description'] as String? ?? '',
            time: e['time'] as String? ?? '',
            endTime: e['endTime'] as String? ?? '',
            category: e['category'] as String? ?? '工作',
            accentColor: Color(e['accentColor'] as int? ?? 0xFF007AFF),
            isCompleted: e['isCompleted'] as bool? ?? false,
          ),
        )
        .toList();
  }

  String _todayKeyStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int get currentIndex => _currentIndex;
  DateTime get selectedDate => _selectedDate;

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    // Load events for new date
    final dateKey = _dateKey(date);
    if (!_allEvents.containsKey(dateKey)) {
      final eventMaps = PersistenceService.getEvents(dateKey);
      _allEvents[dateKey] = eventMaps
          .map(
            (e) => ScheduleEvent(
              id: e['id'] as String? ?? '',
              title: e['title'] as String? ?? '',
              description: e['description'] as String? ?? '',
              time: e['time'] as String? ?? '',
              endTime: e['endTime'] as String? ?? '',
              category: e['category'] as String? ?? '工作',
              accentColor: Color(e['accentColor'] as int? ?? 0xFF007AFF),
              isCompleted: e['isCompleted'] as bool? ?? false,
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // REAL SETTINGS (persisted)
  // ═══════════════════════════════════════════

  String _themeMode = '跟随系统';
  String get themeMode => _themeMode;
  ThemeMode get resolvedThemeMode {
    switch (_themeMode) {
      case '浅色模式':
        return ThemeMode.light;
      case '深色模式':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(String v) {
    _themeMode = v;
    PersistenceService.setThemeMode(v);
    notifyListeners();
  }

  bool _predictiveBack = true;
  bool get predictiveBack => _predictiveBack;
  void setPredictiveBack(bool v) {
    _predictiveBack = v;
    PersistenceService.setPredictiveBack(v);
    notifyListeners();
  }

  bool _blurEffect = true;
  bool get blurEffect => _blurEffect;
  void setBlurEffect(bool v) {
    _blurEffect = v;
    PersistenceService.setBlurEffect(v);
    notifyListeners();
  }

  bool _floatingBar = true;
  bool get floatingBar => _floatingBar;
  void setFloatingBar(bool v) {
    _floatingBar = v;
    PersistenceService.setFloatingBar(v);
    notifyListeners();
  }

  bool _liquidGlass = true;
  bool get liquidGlass => _liquidGlass;
  void setLiquidGlass(bool v) {
    _liquidGlass = v;
    PersistenceService.setLiquidGlass(v);
    notifyListeners();
  }

  String _uiStyle = 'Miuix';
  String get uiStyle => _uiStyle;
  void setUiStyle(String v) {
    _uiStyle = v;
    PersistenceService.setUiStyle(v);
    notifyListeners();
  }

  double get cardRadius {
    switch (_uiStyle) {
      case 'Material':
        return 12;
      case 'iOS':
        return 16;
      default:
        return 20;
    }
  }

  double get cardPadding {
    switch (_uiStyle) {
      case 'Material':
        return 16;
      case 'iOS':
        return 18;
      default:
        return 20;
    }
  }

  double get sectionGap {
    switch (_uiStyle) {
      case 'Material':
        return 20;
      case 'iOS':
        return 24;
      default:
        return 32;
    }
  }

  double get titleSize {
    switch (_uiStyle) {
      case 'Material':
        return 28;
      case 'iOS':
        return 34;
      default:
        return 32;
    }
  }

  FontWeight get titleWeight {
    switch (_uiStyle) {
      case 'Material':
        return FontWeight.w500;
      case 'iOS':
        return FontWeight.w800;
      default:
        return FontWeight.w700;
    }
  }

  double get bottomBarRadius {
    switch (_uiStyle) {
      case 'Material':
        return 16;
      case 'iOS':
        return 24;
      default:
        return 28;
    }
  }

  bool _notifyEnabled = true;
  bool _soundEnabled = false;
  bool _vibrateEnabled = true;
  bool get notifyEnabled => _notifyEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrateEnabled => _vibrateEnabled;
  void setNotifyEnabled(bool v) {
    _notifyEnabled = v;
    notifyListeners();
  }

  void setSoundEnabled(bool v) {
    _soundEnabled = v;
    notifyListeners();
  }

  void setVibrateEnabled(bool v) {
    _vibrateEnabled = v;
    notifyListeners();
  }

  int _pomoDuration = 25;
  int _breakDuration = 5;
  int _longBreakInterval = 4;
  bool _autoBackup = true;
  int get pomoDuration => _pomoDuration;
  int get breakDuration => _breakDuration;
  int get longBreakInterval => _longBreakInterval;
  bool get autoBackup => _autoBackup;
  void setPomoDuration(int v) {
    _pomoDuration = v;
    PersistenceService.setPomoDuration(v);
    notifyListeners();
  }

  void setBreakDuration(int v) {
    _breakDuration = v;
    notifyListeners();
  }

  void setLongBreakInterval(int v) {
    _longBreakInterval = v;
    notifyListeners();
  }

  void setAutoBackup(bool v) {
    _autoBackup = v;
    notifyListeners();
  }

  double _cacheSize = 0;
  double get cacheSize => _cacheSize;
  bool _isClearingCache = false;
  bool get isClearingCache => _isClearingCache;

  /// Calculate actual cache size from temp/cache directories
  Future<void> calculateCacheSize() async {
    double totalMB = 0;
    try {
      if (Platform.isAndroid) {
        // App cache directory
        final cacheDir = await getTemporaryDirectory();
        totalMB += await _dirSizeMB(cacheDir);
        // External cache
        final extCacheDir = await getExternalStorageDirectory();
        if (extCacheDir != null) {
          final updatesDir = Directory('${extCacheDir.path}/updates');
          if (await updatesDir.exists()) {
            totalMB += await _dirSizeMB(updatesDir);
          }
        }
      } else {
        final cacheDir = await getTemporaryDirectory();
        totalMB += await _dirSizeMB(cacheDir);
      }
    } catch (_) {}
    _cacheSize = totalMB;
    notifyListeners();
  }

  Future<double> _dirSizeMB(Directory dir) async {
    int totalBytes = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return totalBytes / (1024 * 1024);
  }

  /// BUG-18 fix: actually compact Hive boxes and clear temp files
  Future<void> clearCache() async {
    _isClearingCache = true;
    notifyListeners();
    try {
      // Compact Hive boxes to reclaim disk space
      await PersistenceService.compactBoxes();
      // Delete temp files
      if (Platform.isAndroid) {
        final cacheDir = await getTemporaryDirectory();
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list()) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
        // Clean update APK files
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final updatesDir = Directory('${extDir.path}/updates');
          if (await updatesDir.exists()) {
            await for (final entity in updatesDir.list()) {
              try {
                await entity.delete(recursive: true);
              } catch (_) {}
            }
          }
        }
      } else {
        final cacheDir = await getTemporaryDirectory();
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list()) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
      _cacheSize = 0.0;
    } catch (_) {
      _cacheSize = 0.0;
    }
    _isClearingCache = false;
    notifyListeners();
  }

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  Future<bool> exportData() async {
    _isExporting = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _isExporting = false;
    notifyListeners();
    return true;
  }

  // ═══════════════════════════════════════════
  // SCHEDULE EVENTS - per date with persistence
  // ═══════════════════════════════════════════

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  final Map<String, List<ScheduleEvent>> _allEvents = {};

  List<ScheduleEvent> get events {
    final key = _dateKey(_selectedDate);
    return _allEvents[key] ?? [];
  }

  List<ScheduleEvent> get allEvents =>
      _allEvents.values.expand((e) => e).toList();

  void _persistEvents(String dateKey) {
    final evts = _allEvents[dateKey] ?? [];
    PersistenceService.setEvents(
      dateKey,
      evts
          .map(
            (e) => {
              'id': e.id,
              'title': e.title,
              'description': e.description,
              'time': e.time,
              'endTime': e.endTime,
              'category': e.category,
              'accentColor': e.accentColor.toARGB32(),
              'isCompleted': e.isCompleted,
            },
          )
          .toList(),
    );
    _scheduleSync();
  }

  // Optimization: O(1) lookup map for event IDs
  final Map<String, String> _eventIdToKey = {};

  void toggleEvent(String id) {
    final key = _eventIdToKey[id];
    if (key == null) return;
    final events = _allEvents[key];
    if (events == null) return;
    final idx = events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    events[idx] = events[idx].copyWith(isCompleted: !events[idx].isCompleted);
    _persistEvents(key);
    _updateWeeklyProductivity();
    notifyListeners();
  }

  void addEvent(ScheduleEvent event) {
    final key = _dateKey(_selectedDate);
    _allEvents.putIfAbsent(key, () => []);
    _allEvents[key]!.add(event);
    _eventIdToKey[event.id] = key; // Update lookup index
    _persistEvents(key);
    notifyListeners();
  }

  void removeEvent(String id) {
    final key = _eventIdToKey[id];
    if (key == null) return;
    final events = _allEvents[key];
    if (events == null) return;
    final idx = events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    events.removeAt(idx);
    _eventIdToKey.remove(id); // Clean up lookup index
    _persistEvents(key);
    _updateWeeklyProductivity();
    notifyListeners();
  }

  double get completionRate {
    final evts = events;
    if (evts.isEmpty) return 0;
    return evts.where((e) => e.isCompleted).length / evts.length;
  }

  void _updateWeeklyProductivity() {
    final now = DateTime.now();
    final weekday = now.weekday - 1; // 0-6
    final weekly = PersistenceService.getWeeklyProductivity();
    weekly[weekday] = completionRate;
    PersistenceService.setWeeklyProductivity(weekly);
  }

  // ═══ Habits (persisted) ═══
  final List<HabitItem> _habits = [];
  List<HabitItem> get habits => _habits;

  void _persistHabits() {
    PersistenceService.setHabits(
      _habits
          .map(
            (h) => {
              'id': h.id,
              'title': h.title,
              'icon': h.icon,
              'streak': h.streak,
              'color': h.color.toARGB32(),
            },
          )
          .toList(),
    );
    _scheduleSync();
  }

  void addHabit(HabitItem habit) {
    _habits.add(habit);
    _persistHabits();
    notifyListeners();
  }

  void removeHabit(String id) {
    _habits.removeWhere((h) => h.id == id);
    _persistHabits();
    notifyListeners();
  }

  void toggleHabit(String id) {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final habit = _habits[index];
      final todayKey = _todayKeyStr();
      final dates = PersistenceService.getHabitCompletionDates(id);

      if (!habit.todayCompleted) {
        if (!dates.contains(todayKey)) dates.add(todayKey);
      } else {
        dates.remove(todayKey);
      }
      // BUG-17 fix: recalculate streak from actual completion dates
      final streak = _calculateStreak(dates);
      _habits[index] = habit.copyWith(
        todayCompleted: !habit.todayCompleted,
        streak: streak,
      );
      PersistenceService.setHabitCompletionDates(id, dates);
      _persistHabits();
      notifyListeners();
    }
  }

  /// BUG-17 fix: Calculate consecutive streak ending today (or yesterday)
  int _calculateStreak(List<String> dateStrs) {
    if (dateStrs.isEmpty) return 0;
    // Parse all dates
    final dates = <DateTime>[];
    for (final s in dateStrs) {
      final parts = s.split('-');
      if (parts.length == 3) {
        final d = DateTime.tryParse(
          '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}',
        );
        if (d != null) dates.add(d);
      }
    }
    if (dates.isEmpty) return 0;
    dates.sort((a, b) => b.compareTo(a)); // newest first

    // Check if chain starts from today or yesterday
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final first = DateTime(dates[0].year, dates[0].month, dates[0].day);
    final diff = todayNorm.difference(first).inDays;
    if (diff > 1) return 0; // chain broken

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = DateTime(
        dates[i - 1].year,
        dates[i - 1].month,
        dates[i - 1].day,
      );
      final cur = DateTime(dates[i].year, dates[i].month, dates[i].day);
      if (prev.difference(cur).inDays == 1) {
        streak++;
      } else if (prev.difference(cur).inDays == 0) {
        continue; // same day duplicate
      } else {
        break;
      }
    }
    return streak;
  }

  // ═══ Goals (persisted) ═══
  final List<GoalItem> _goals = [];
  List<GoalItem> get goals => _goals;

  void _persistGoals() {
    PersistenceService.setGoals(
      _goals
          .map(
            (g) => {
              'id': g.id,
              'title': g.title,
              'icon': g.icon,
              'progress': g.progress,
              'color': g.color.toARGB32(),
              'target': g.target,
            },
          )
          .toList(),
    );
    _scheduleSync();
  }

  void addGoal(GoalItem goal) {
    _goals.add(goal);
    _persistGoals();
    notifyListeners();
  }

  void removeGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    _persistGoals();
    notifyListeners();
  }

  void updateGoalProgress(String id, double progress) {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      final g = _goals[index];
      _goals[index] = GoalItem(
        id: g.id,
        title: g.title,
        icon: g.icon,
        progress: progress.clamp(0.0, 1.0),
        color: g.color,
        target: g.target,
      );
      _persistGoals();
      notifyListeners();
    }
  }

  // ═══ Pomodoro (persisted) ═══
  int _pomodoroCount = 0;
  int _focusMinutes = 0;
  int get pomodoroCount => _pomodoroCount;
  int get focusMinutes => _focusMinutes;
  String get focusTimeFormatted {
    int h = _focusMinutes ~/ 60;
    int m = _focusMinutes % 60;
    return '${h}h ${m}m';
  }

  void addPomodoro() {
    _pomodoroCount++;
    _focusMinutes += _pomoDuration;
    PersistenceService.setPomodoroCount(_pomodoroCount);
    PersistenceService.setFocusMinutes(_focusMinutes);
    _scheduleSync();
    notifyListeners();
  }

  // ═══ Weekly Stats (persisted) ═══
  /// BUG-12 fix: getter is now pure read-only, no side-effects
  List<double> get weeklyProductivity {
    final data = PersistenceService.getWeeklyProductivity();
    // Overlay today's live completion rate (read-only, don't persist here)
    final weekday = DateTime.now().weekday - 1;
    if (weekday >= 0 && weekday < data.length) {
      data[weekday] = completionRate;
    }
    return List.unmodifiable(data);
  }
}
