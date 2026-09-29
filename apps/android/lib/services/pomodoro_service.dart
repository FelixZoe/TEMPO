import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/app_provider.dart';
import '../services/persistence_service.dart';
import '../theme/miui_theme.dart';

/// Pomodoro focus session phases.
enum PomodoroPhase { idle, focus, shortBreak, longBreak }

/// Centralized Pomodoro service with:
/// - Focus / short break / long break cycling
/// - Lock-screen ongoing notification with live countdown
/// - System notifications for all events (no in-app overlay)
class PomodoroService extends ChangeNotifier {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  // -- State --
  PomodoroPhase _phase = PomodoroPhase.idle;
  int _seconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  int _sessionCount = 0; // sessions since last long break
  bool _halfNotified = false;
  bool _fiveMinNotified = false;
  bool _oneMinNotified = false;

  // -- Config (pulled from AppProvider) --
  int focusMinutes = 25;
  int shortBreakMinutes = 5;
  int longBreakMinutes = 15;
  int sessionsBeforeLongBreak = 4;

  // -- Getters --
  PomodoroPhase get phase => _phase;
  int get seconds => _seconds;
  bool get isRunning => _isRunning;
  bool get isActive => _phase != PomodoroPhase.idle;
  int get sessionCount => _sessionCount;
  double get progress {
    final total = _totalSeconds;
    if (total <= 0) return 0;
    return 1.0 - (_seconds / total);
  }

  int get _totalSeconds {
    switch (_phase) {
      case PomodoroPhase.focus:
        return focusMinutes * 60;
      case PomodoroPhase.shortBreak:
        return shortBreakMinutes * 60;
      case PomodoroPhase.longBreak:
        return longBreakMinutes * 60;
      case PomodoroPhase.idle:
        return focusMinutes * 60;
    }
  }

  String get phaseLabel {
    switch (_phase) {
      case PomodoroPhase.focus:
        return '专注中';
      case PomodoroPhase.shortBreak:
        return '短休息';
      case PomodoroPhase.longBreak:
        return '长休息';
      case PomodoroPhase.idle:
        return '番茄专注';
    }
  }

  Color get phaseColor {
    switch (_phase) {
      case PomodoroPhase.focus:
        return MiuiColors.blue;
      case PomodoroPhase.shortBreak:
        return MiuiColors.green;
      case PomodoroPhase.longBreak:
        return MiuiColors.teal;
      case PomodoroPhase.idle:
        return MiuiColors.blue;
    }
  }

  String get timeDisplay {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -- Notification plugin --
  final FlutterLocalNotificationsPlugin _notify =
      FlutterLocalNotificationsPlugin();
  bool _notifyInit = false;
  static const _channelOngoing = 'pomodoro_ongoing';
  static const _channelAlert = 'pomodoro_alert';
  static const _notifId = 88888;

  AppProvider? _provider;

  void bindContext(BuildContext ctx, AppProvider provider) {
    _provider = provider;
    focusMinutes = provider.pomoDuration;
  }

  // -- Actions --

  /// Start a focus session from idle.
  void startFocus() {
    _phase = PomodoroPhase.focus;
    _seconds = focusMinutes * 60;
    _halfNotified = false;
    _fiveMinNotified = false;
    _oneMinNotified = false;
    _startTimer();
    _showSystemAlert('开始专注', '$focusMinutes 分钟倒计时');
    _updateOngoingNotification();
    notifyListeners();
  }

  /// Toggle pause/resume.
  void togglePause() {
    if (_phase == PomodoroPhase.idle) {
      startFocus();
      return;
    }
    if (_isRunning) {
      _pause();
    } else {
      _resume();
    }
  }

  void _pause() {
    _isRunning = false;
    _timer?.cancel();
    _showSystemAlert(
      '已暂停',
      '剩余 ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
    );
    _updateOngoingNotification();
    notifyListeners();
  }

  void _resume() {
    _startTimer();
    _showSystemAlert(
      '继续${_phase == PomodoroPhase.focus ? "专注" : "休息"}',
      '剩余 ${_seconds ~/ 60} 分钟',
    );
    _updateOngoingNotification();
    notifyListeners();
  }

  /// Reset to idle.
  void reset() {
    _timer?.cancel();
    _isRunning = false;
    _phase = PomodoroPhase.idle;
    _seconds = focusMinutes * 60;
    _sessionCount = 0;
    _cancelOngoingNotification();
    notifyListeners();
  }

  /// Skip current phase (e.g. skip rest).
  void skipPhase() {
    _timer?.cancel();
    _isRunning = false;
    if (_phase == PomodoroPhase.focus) {
      // Skipping focus = abandon this session
      _phase = PomodoroPhase.idle;
      _seconds = focusMinutes * 60;
      _cancelOngoingNotification();
    } else {
      // Skipping break = start next focus
      startFocus();
      return;
    }
    notifyListeners();
  }

  // -- Timer logic --

  void _startTimer() {
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        _seconds--;
        // Update lock-screen notification every 5 seconds (save battery)
        if (_seconds % 5 == 0) {
          _updateOngoingNotification();
        }
        // Milestone notifications during focus
        if (_phase == PomodoroPhase.focus) {
          _checkFocusMilestones();
        }
        notifyListeners();
      } else {
        _onPhaseComplete();
      }
    });
  }

  void _checkFocusMilestones() {
    final total = focusMinutes * 60;
    final elapsed = total - _seconds;
    final half = total ~/ 2;

    // Half-way notification
    if (!_halfNotified && elapsed >= half && total > 120) {
      _halfNotified = true;
      _showSystemAlert('已过半', '还剩 ${_seconds ~/ 60} 分钟');
    }
    // 5 minutes left
    if (!_fiveMinNotified && _seconds <= 300 && _seconds > 295 && total > 600) {
      _fiveMinNotified = true;
      _showSystemAlert('还剩 5 分钟', '最后冲刺');
    }
    // 1 minute left
    if (!_oneMinNotified && _seconds <= 60 && _seconds > 55) {
      _oneMinNotified = true;
      _showSystemAlert('最后 1 分钟', '即将完成');
    }
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    _isRunning = false;
    HapticFeedback.heavyImpact();

    switch (_phase) {
      case PomodoroPhase.focus:
        // Focus complete -> record + start break
        _sessionCount++;
        _provider?.addPomodoro();
        PersistenceService.recordDailyPomodoro();

        final totalMin = _provider?.focusMinutes ?? 0;
        final totalCount = _provider?.pomodoroCount ?? 0;
        _showSystemAlert(
          '专注完成',
          '第 $_sessionCount 轮 · 本次 $focusMinutes min · 今日 $totalCount 次 ${totalMin}min',
          highPriority: true,
        );

        // Milestone notifications
        final totalToday = _provider?.pomodoroCount ?? 0;
        if (totalToday == 4) {
          Future.delayed(const Duration(seconds: 3), () {
            _showSystemAlert('今日第 4 次专注', '节奏不错，继续', highPriority: true);
          });
        } else if (totalToday == 8) {
          Future.delayed(const Duration(seconds: 3), () {
            _showSystemAlert('今日第 8 次专注', '高效状态，注意休息', highPriority: true);
          });
        }

        // Start break phase
        if (_sessionCount >= sessionsBeforeLongBreak) {
          _phase = PomodoroPhase.longBreak;
          _seconds = longBreakMinutes * 60;
          _sessionCount = 0;
          Future.delayed(const Duration(seconds: 1), () {
            _showSystemAlert('长休息', '$longBreakMinutes 分钟');
          });
        } else {
          _phase = PomodoroPhase.shortBreak;
          _seconds = shortBreakMinutes * 60;
        }
        // Auto-start break
        _halfNotified = false;
        _fiveMinNotified = false;
        _oneMinNotified = false;
        _startTimer();

      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        // Break complete -> prompt next focus
        _showSystemAlert('休息结束', '准备好继续了吗', highPriority: true);
        _phase = PomodoroPhase.idle;
        _seconds = focusMinutes * 60;
        _cancelOngoingNotification();

      case PomodoroPhase.idle:
        break;
    }
    notifyListeners();
  }

  // -- System notifications (all notifications are system-level) --

  Future<void> _initNotify() async {
    if (_notifyInit || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _notify.initialize(settings);

      if (Platform.isAndroid) {
        final plugin = _notify
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Ongoing channel (low importance, no sound)
        await plugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelOngoing,
            '番茄专注',
            description: '番茄专注计时器实时显示',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
        // Alert channel (high importance, sound)
        await plugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelAlert,
            '番茄提醒',
            description: '番茄阶段完成、里程碑等提醒',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
      _notifyInit = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Pomodoro] notification init failed: $e');
    }
  }

  Future<void> _updateOngoingNotification() async {
    if (kIsWeb) return;
    await _initNotify();
    if (!_notifyInit) return;

    final todayCount =
        (_provider?.pomodoroCount ?? 0) +
        (_phase == PomodoroPhase.focus ? 1 : 0);
    final todayFocus = _provider?.focusMinutes ?? 0;
    final pct = (progress * 100).toInt();
    final title = _isRunning
        ? '$phaseLabel  $timeDisplay'
        : '$phaseLabel · 已暂停';
    final body = '第 $todayCount 次 · 今日 ${todayFocus}min · $pct%';

    try {
      await _notify.show(
        _notifId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelOngoing,
            '番茄专注',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: false,
            playSound: false,
            enableVibration: false,
            icon: '@mipmap/ic_launcher',
            subText: 'TEMPO',
            category: AndroidNotificationCategory.progress,
            showProgress: true,
            maxProgress: 100,
            progress: pct,
            usesChronometer: true,
            chronometerCountDown: true,
            when: DateTime.now()
                .add(Duration(seconds: _seconds))
                .millisecondsSinceEpoch,
            visibility: NotificationVisibility.public,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Pomodoro] ongoing notification error: $e');
    }
  }

  /// System alert — clean, one line, no emoji
  Future<void> _showSystemAlert(
    String title,
    String body, {
    bool highPriority = false,
  }) async {
    if (kIsWeb) return;
    await _initNotify();
    if (!_notifyInit) return;

    if (_provider?.vibrateEnabled ?? true) {
      if (highPriority) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    try {
      await _notify.show(
        _notifId + 1 + DateTime.now().millisecond % 100,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelAlert,
            '番茄提醒',
            importance: highPriority
                ? Importance.high
                : Importance.defaultImportance,
            priority: highPriority ? Priority.high : Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            subText: 'TEMPO',
            visibility: NotificationVisibility.public,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Pomodoro] system alert error: $e');
    }
  }

  Future<void> _cancelOngoingNotification() async {
    if (kIsWeb) return;
    try {
      await _notify.cancel(_notifId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelOngoingNotification();
    super.dispose();
  }
}
