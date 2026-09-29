import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// ReminderService — periodic schedule & habit reminder engine.
///
/// Checks every 30 seconds:
///  - Schedule events starting within 5 minutes → in-app + system notification
///  - Schedule events that just ended → in-app notification
///  - Daily habit reminder at configurable time (default 21:00)
///
/// Also provides immediate feedback methods:
///  - [onHabitToggled] — called when user completes a habit
///  - [onEventToggled] — called when user marks an event done
///  - [onGoalProgress] — called when goal progress changes
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  Timer? _timer;
  BuildContext? _context;
  AppProvider? _provider;
  bool _running = false;

  // Track which events/habits we already notified to avoid duplicates
  final Set<String> _notifiedUpcoming = {}; // event IDs notified as "upcoming"
  final Set<String> _notifiedEnded = {}; // event IDs notified as "ended"
  bool _habitReminderSentToday = false;
  bool _morningGreetingSent = false;
  bool _eveningSummarySent = false;
  String _lastHabitReminderDate = '';

  // System notification plugin (reuse if already initialised elsewhere)
  final FlutterLocalNotificationsPlugin _sysNotify =
      FlutterLocalNotificationsPlugin();
  bool _sysInitialised = false;

  // ═══ Notification channel IDs ═══
  static const _channelSchedule = 'schedule_reminder';
  static const _channelHabit = 'habit_reminder';

  /// Start the periodic checker. Call once in MainShell.initState.
  void start(BuildContext context, AppProvider provider) {
    _context = context;
    _provider = provider;
    if (_running) return;
    _running = true;

    _initSystemNotifications();

    // Initial check after 5 seconds
    Future.delayed(const Duration(seconds: 5), _tick);

    // Then every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// Update context reference (call in didChangeDependencies if needed)
  void updateContext(BuildContext context, AppProvider provider) {
    _context = context;
    _provider = provider;
  }

  // ═══════════════════════════════════════════
  //  Core tick — runs every 30 s
  // ═══════════════════════════════════════════
  void _tick() {
    if (_provider == null || _context == null) return;
    if (!(_provider!.notifyEnabled)) return;

    final now = DateTime.now();
    // Use the same dateKey format as PersistenceService (no zero-padding)
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Reset daily trackers at midnight
    if (_lastHabitReminderDate != todayKey) {
      _habitReminderSentToday = false;
      _morningGreetingSent = false;
      _eveningSummarySent = false;
      _lastHabitReminderDate = todayKey;
      _notifiedUpcoming.clear();
      _notifiedEnded.clear();
    }

    _checkScheduleEvents(now);
    _checkHabitReminder(now);
    _checkProactiveNotifications(now);
  }

  // ═══════════════════════════════════════════
  //  Schedule event reminders
  // ═══════════════════════════════════════════
  void _checkScheduleEvents(DateTime now) {
    final events = _provider?.events ?? [];

    for (final event in events) {
      if (event.isCompleted) continue;

      final startTime = _parseTime(event.time, now);
      final endTime = event.endTime.isNotEmpty
          ? _parseTime(event.endTime, now)
          : null;

      if (startTime == null) continue;

      // ── Upcoming: 5 minutes before start ──
      final minutesBefore = startTime.difference(now).inMinutes;
      if (minutesBefore > 0 &&
          minutesBefore <= 5 &&
          !_notifiedUpcoming.contains(event.id)) {
        _notifiedUpcoming.add(event.id);
        _showSystemNotification(
          id: event.id.hashCode & 0x7FFFFFFF,
          channel: _channelSchedule,
          title: '日程即将开始',
          body: '${event.title} 将在 $minutesBefore 分钟后开始',
        );
      }

      // ── Just ended: within 2 minutes after end time ──
      if (endTime != null) {
        final minutesAfterEnd = now.difference(endTime).inMinutes;
        if (minutesAfterEnd >= 0 &&
            minutesAfterEnd <= 2 &&
            !_notifiedEnded.contains(event.id)) {
          _notifiedEnded.add(event.id);
          _showSystemNotification(
            id: (event.id.hashCode + 1) & 0x7FFFFFFF,
            channel: _channelSchedule,
            title: '日程已结束',
            body: '${event.title} 已到结束时间，记得标记完成',
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════
  //  Habit daily reminder
  // ═══════════════════════════════════════════
  void _checkHabitReminder(DateTime now) {
    if (_habitReminderSentToday) return;
    final habits = _provider?.habits ?? [];
    if (habits.isEmpty) return;

    // Remind at 21:00 if there are uncompleted habits
    if (now.hour >= 21 && now.hour < 22) {
      final uncompleted = habits.where((h) => !h.todayCompleted).toList();
      if (uncompleted.isNotEmpty) {
        _habitReminderSentToday = true;
        final names = uncompleted.map((h) => h.title).take(3).join('、');
        final suffix = uncompleted.length > 3
            ? ' 等${uncompleted.length}个习惯'
            : '';

        _showSystemNotification(
          id: 99001,
          channel: _channelHabit,
          title: '习惯打卡提醒',
          body: '$names$suffix 还未完成，记得打卡哦！',
        );
      }
    }
  }

  // ═══════════════════════════════════════════
  //  Proactive time-based notifications (optimized)
  //  Only send when there's meaningful content to show.
  //  Removed low-value notifications (lunch, afternoon)
  //  to reduce notification fatigue.
  // ═══════════════════════════════════════════
  void _checkProactiveNotifications(DateTime now) {
    final events = _provider?.events ?? [];
    final habits = _provider?.habits ?? [];
    final pomCount = _provider?.pomodoroCount ?? 0;

    // 🌅 Morning greeting (8:00-8:10) — only if there are pending tasks
    if (!_morningGreetingSent && now.hour == 8 && now.minute < 10) {
      _morningGreetingSent = true;
      final pending = events.where((e) => !e.isCompleted).length;
      final unfinishedHabits = habits.where((h) => !h.todayCompleted).length;
      // Only notify if there's something worth mentioning
      if (pending > 0 || unfinishedHabits > 0) {
        final parts = <String>[];
        if (pending > 0) parts.add('$pending 项日程');
        if (unfinishedHabits > 0) parts.add('$unfinishedHabits 个习惯');
        _showSystemNotification(
          id: 99010,
          channel: _channelSchedule,
          title: '早上好',
          body: '今天有 ${parts.join('、')} 待完成',
        );
      }
    }

    // 🌙 Evening summary (20:00-20:10) — only if user was productive today
    if (!_eveningSummarySent && now.hour == 20 && now.minute < 10) {
      _eveningSummarySent = true;
      final completed = events.where((e) => e.isCompleted).length;
      final total = events.length;
      final habitDone = habits.where((h) => h.todayCompleted).length;
      final habitTotal = habits.length;

      // Only send summary if the user actually did something today
      if (completed > 0 || pomCount > 0 || habitDone > 0) {
        final parts = <String>[];
        if (total > 0) parts.add('日程 $completed/$total');
        if (pomCount > 0) parts.add('番茄 $pomCount 个');
        if (habitTotal > 0) parts.add('习惯 $habitDone/$habitTotal');
        _showSystemNotification(
          id: 99011,
          channel: _channelSchedule,
          title: '今日回顾',
          body: parts.join(' · '),
        );
      }
    }
  }

  // ═══════════════════════════════════════════
  //  Immediate feedback: habit toggled (optimized)
  //  Consolidated: only milestone or all-done triggers
  //  a system notification. Regular check-offs use
  //  in-app feedback only (handled by UI layer).
  // ═══════════════════════════════════════════
  /// Call this from AppProvider.toggleHabit or from the UI after toggling.
  void onHabitToggled(BuildContext context, HabitItem habit, bool completed) {
    if (!(_provider?.notifyEnabled ?? true)) return;

    if (completed) {
      // Streak milestones — only notify on significant streaks
      String? milestone;
      if (habit.streak == 7) milestone = '连续 7 天！坚持就是胜利';
      if (habit.streak == 30) milestone = '连续 30 天！了不起';
      if (habit.streak == 100) milestone = '连续 100 天！习惯已养成';
      if (habit.streak == 365) milestone = '连续 365 天！传奇级自律';

      // Only send system notification for milestones (reduce notification spam)
      if (milestone != null) {
        _showSystemNotification(
          id: 99030 + habit.streak,
          channel: _channelHabit,
          title: '${habit.title} 里程碑',
          body: milestone,
        );
      }

      // Check if all habits completed today
      final allHabits = _provider?.habits ?? [];
      final allDone = allHabits.every(
        (h) => h.todayCompleted || h.id == habit.id,
      );
      if (allDone && allHabits.length > 1) {
        _showSystemNotification(
          id: 99040,
          channel: _channelHabit,
          title: '今日习惯全部完成',
          body: '${allHabits.length} 个习惯全部打卡，继续保持！',
        );
      }
    }
  }

  // ═══════════════════════════════════════════
  //  Immediate feedback: event toggled
  // ═══════════════════════════════════════════
  void onEventToggled(
    BuildContext context,
    ScheduleEvent event,
    bool completed,
  ) {
    if (!(_provider?.notifyEnabled ?? true)) return;

    if (completed) {
      // Only send system notification when ALL events are done (reduce spam)
      // Individual event completion feedback is handled in-app by the UI
      final events = _provider?.events ?? [];
      final total = events.length;
      final done = events.where((e) => e.isCompleted).length + 1;
      if (total > 1 && done == total) {
        _showSystemNotification(
          id: 99050,
          channel: _channelSchedule,
          title: '今日日程全部完成',
          body: '$total 项日程全部搞定！',
        );
      }
    }
  }

  // ═══════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════
  DateTime? _parseTime(String timeStr, DateTime today) {
    // Expected format: "HH:mm" or "HH:mm:ss"
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return null;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateTime(today.year, today.month, today.day, h, m);
    } catch (_) {
      return null;
    }
  }

  // ═══ System-level notifications (Android) ═══
  Future<void> _initSystemNotifications() async {
    if (_sysInitialised || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _sysNotify.initialize(settings);

      if (Platform.isAndroid) {
        final androidPlugin = _sysNotify
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Create notification channels
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelSchedule,
            '日程提醒',
            description: '日程即将开始或结束时提醒',
            importance: Importance.high,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelHabit,
            '习惯提醒',
            description: '每日习惯打卡提醒',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'pomodoro_ongoing',
            '番茄专注',
            description: '番茄专注计时器实时显示',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'pomodoro_alert',
            '番茄完成提醒',
            description: '专注完成与休息结束提醒',
            importance: Importance.high,
          ),
        );
      }
      _sysInitialised = true;
    } catch (e) {
      if (kDebugMode)
        debugPrint('ReminderService: system notification init failed: $e');
    }
  }

  Future<void> _showSystemNotification({
    required int id,
    required String channel,
    required String title,
    required String body,
  }) async {
    if (!_sysInitialised || kIsWeb) return;
    // Haptic feedback for system notifications
    if (_provider?.vibrateEnabled ?? true) {
      HapticFeedback.heavyImpact();
    }
    try {
      await _sysNotify.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channel == _channelSchedule ? '日程提醒' : '习惯提醒',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode)
        debugPrint('ReminderService: show notification failed: $e');
    }
  }
}
