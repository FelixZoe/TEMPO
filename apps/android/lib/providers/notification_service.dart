import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/miui_theme.dart';

/// In-app overlay notification service.
///
/// Displays a clean, modern notification banner at the top of the screen
/// with smooth enter/exit animations and optional haptic feedback.
class NotificationService {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// Whether haptic feedback is enabled (synced from AppProvider.vibrateEnabled)
  static bool vibrateEnabled = true;

  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.notifications_rounded,
    Color color = MiuiColors.blue,
    Duration duration = const Duration(seconds: 3),
    bool vibrate = true,
  }) {
    dismiss();

    // Haptic feedback when notification appears
    if (vibrate && vibrateEnabled) {
      HapticFeedback.mediumImpact();
    }

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (_) => _NotificationOverlay(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onDismiss: dismiss,
      ),
    );
    overlay.insert(_currentOverlay!);
    _dismissTimer = Timer(duration, dismiss);
  }

  static void showPomodoroComplete(BuildContext context) {
    show(
      context,
      title: '🍅 番茄完成！',
      subtitle: '专注时间结束，休息一下吧',
      icon: Icons.check_circle_rounded,
      color: MiuiColors.green,
      duration: const Duration(seconds: 5),
    );
  }

  static void showTaskReminder(BuildContext context, String taskName) {
    show(
      context,
      title: '日程提醒',
      subtitle: taskName,
      icon: Icons.calendar_today_rounded,
      color: MiuiColors.blue,
    );
  }

  static void showHabitComplete(
    BuildContext context,
    String habitName,
    int streak,
  ) {
    show(
      context,
      title: '$habitName 打卡成功',
      subtitle: '已连续 $streak 天，继续保持！',
      icon: Icons.local_fire_department_rounded,
      color: MiuiColors.green,
    );
  }

  static void showPomodoroStart(BuildContext context, int minutes) {
    show(
      context,
      title: '番茄开始',
      subtitle: '专注 $minutes 分钟，加油！',
      icon: Icons.timer_rounded,
      color: MiuiColors.orange,
      duration: const Duration(seconds: 2),
    );
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _NotificationOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;
  const _NotificationOverlay({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });
  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide, _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slide = Tween<double>(
      begin: -80,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted)
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        top: MediaQuery.of(context).padding.top + _slide.value,
        left: 0,
        right: 0,
        child: Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! < 0)
                  _ctrl.reverse().then((_) => widget.onDismiss());
              },
              child: _buildNotification(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotification(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : MiuiColors.textPrimary,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : MiuiColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '现在',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : MiuiColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
