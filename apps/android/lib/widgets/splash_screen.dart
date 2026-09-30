import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/miui_theme.dart';

/// Premium animated splash screen with staggered entrance animations.
/// Displays the app icon, title, tagline, and a custom loading indicator.
///
/// The exit is handled by the parent [_SplashGate] via a cross-fade,
/// so this widget only manages the entrance + idle animations.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _loadingController;

  // Staggered entrance animations
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _loaderOpacity;

  // Subtle pulse on icon after entrance
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // --- Entrance: 1000ms staggered ---
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
          ),
        );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
          ),
        );
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // --- Subtle pulse ---
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // --- Loading spinner ---
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Start entrance
    _entranceController.forward().then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
        _loadingController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? MiuiColors.darkBackground : MiuiColors.background;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _pulseController,
        _loadingController,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bgColor,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Animated Logo ---
                Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value * _pulse.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: MiuiColors.primary.withValues(
                              alpha: 0.2 * _iconOpacity.value,
                            ),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- App Title ---
                SlideTransition(
                  position: _titleSlide,
                  child: Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      'Tempo',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? MiuiColors.darkTextPrimary
                            : MiuiColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // --- Tagline ---
                SlideTransition(
                  position: _taglineSlide,
                  child: Opacity(
                    opacity: _taglineOpacity.value,
                    child: Text(
                      '专注高效的个人效率工具',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                        color: isDark
                            ? MiuiColors.darkTextSecondary
                            : MiuiColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 44),

                // --- Custom Loading Indicator ---
                Opacity(
                  opacity: _loaderOpacity.value,
                  child: _FlowingDotsLoader(
                    animation: _loadingController,
                    color: MiuiColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A smooth 3-dot "flowing" loading indicator.
class _FlowingDotsLoader extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  const _FlowingDotsLoader({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = (animation.value + i * 0.33) % 1.0;
              final scale = 0.4 + 0.6 * math.sin(t * math.pi);
              final opacity = 0.3 + 0.7 * math.sin(t * math.pi);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8 * scale,
                height: 8 * scale,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Generic loading state widget with custom arc spinner + optional text.
class FlowLoadingIndicator extends StatefulWidget {
  final String? message;
  final double size;
  const FlowLoadingIndicator({super.key, this.message, this.size = 36});

  @override
  State<FlowLoadingIndicator> createState() => _FlowLoadingIndicatorState();
}

class _FlowLoadingIndicatorState extends State<FlowLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            );
          },
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ArcSpinnerPainter(
              color: MiuiColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArcSpinnerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _ArcSpinnerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 2 * math.pi, false, paint);
    paint.color = color;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 0.75,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcSpinnerPainter oldDelegate) => false;
}
