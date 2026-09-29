import 'dart:ui';
import 'package:flutter/material.dart';

/// Apple-level breathing design system with full dark mode + liquid glass
class MiuiColors {
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryLight = Color(0xFFE8F0FE);

  // Light palette
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFF2F2F7);
  static const Color surfaceAlt = Color(0xFFF7F7F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E5EA);
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFC7C7CC);

  // Dark palette — warm dark grey to reduce eye strain
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1E1E22);
  static const Color darkSurfaceAlt = Color(0xFF2A2A2E);
  static const Color darkCard = Color(0xFF1E1E22);
  static const Color darkDivider = Color(0xFF3A3A3E);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF98989D);
  static const Color darkTextTertiary = Color(0xFF6C6C72);

  // Accent palette
  static const Color blue = Color(0xFF007AFF);
  static const Color orange = Color(0xFFFF9500);
  static const Color green = Color(0xFF34C759);
  static const Color purple = Color(0xFFAF52DE);
  static const Color red = Color(0xFFFF3B30);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color pink = Color(0xFFFF2D55);
  static const Color yellow = Color(0xFFFFCC00);

  static const List<Color> cardAccents = [
    blue,
    orange,
    green,
    purple,
    red,
    teal,
    pink,
    yellow,
  ];
}

/// Breathing spacing constants
class Breathing {
  static const double pagePaddingH = 20;
  static const double sectionGap = 32;
  static const double cardGap = 14;
  static const double cardRadius = 20;
  static const double cardPadding = 20;
  static const double smallRadius = 14;
  static const double titleSize = 32;
  static const double subtitleSize = 15;
}

/// Adaptive colors that respond to theme brightness
class AppColors {
  final bool isDark;
  AppColors(this.isDark);

  Color get background =>
      isDark ? MiuiColors.darkBackground : MiuiColors.background;
  Color get surface => isDark ? MiuiColors.darkSurface : MiuiColors.surface;
  Color get surfaceAlt =>
      isDark ? MiuiColors.darkSurfaceAlt : MiuiColors.surfaceAlt;
  Color get card => isDark ? MiuiColors.darkCard : MiuiColors.card;
  Color get divider => isDark ? MiuiColors.darkDivider : MiuiColors.divider;
  Color get textPrimary =>
      isDark ? MiuiColors.darkTextPrimary : MiuiColors.textPrimary;
  Color get textSecondary =>
      isDark ? MiuiColors.darkTextSecondary : MiuiColors.textSecondary;
  Color get textTertiary =>
      isDark ? MiuiColors.darkTextTertiary : MiuiColors.textTertiary;

  // Enhanced glass card colors - much more visible
  Color get glassBackground => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.65);
  Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.7);
  Color get glassHighlight => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.85);

  // Bottom bar glass
  Color get barGlassBackground => isDark
      ? const Color(0xFF121214).withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.55);
  Color get barGlassBorder => isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.06);

  static AppColors of(BuildContext context) {
    return AppColors(Theme.of(context).brightness == Brightness.dark);
  }
}

class MiuiTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? MiuiColors.darkBackground : MiuiColors.background;
    final cardColor = isDark ? MiuiColors.darkCard : MiuiColors.card;
    final textColor = isDark
        ? MiuiColors.darkTextPrimary
        : MiuiColors.textPrimary;
    final divColor = isDark ? MiuiColors.darkDivider : MiuiColors.divider;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: MiuiColors.primary,
              surface: MiuiColors.darkSurface,
              onSurface: MiuiColors.darkTextPrimary,
            )
          : const ColorScheme.light(
              primary: MiuiColors.primary,
              surface: MiuiColors.background,
              onSurface: MiuiColors.textPrimary,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MiuiColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Breathing.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: divColor, thickness: 0.5, space: 0),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? MiuiColors.darkSurfaceAlt
            : MiuiColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Apple-style frosted glass card — matches iOS UIVisualEffectView MaterialWithBlurringContent
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enabled;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = Breathing.cardRadius,
    this.padding,
    this.margin,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (!enabled) {
      return Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(Breathing.cardPadding),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      );
    }

    // iOS 18 liquid glass style: layered blur with vibrancy tint
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          // iOS uses ~30pt gaussian blur + vibrancy saturation;
          // Using sigma=30 for natural iOS-like frosted glass feel
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: padding ?? const EdgeInsets.all(Breathing.cardPadding),
            decoration: BoxDecoration(
              // iOS system material tint — more translucent than before
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.isDark
                    ? [
                        const Color(0xFF2A2A2E).withValues(alpha: 0.55),
                        const Color(0xFF1E1E22).withValues(alpha: 0.50),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.55),
                      ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              // iOS 0.33pt hairline border
              border: Border.all(
                color: colors.isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.80),
                width: 0.33,
              ),
              boxShadow: [
                // iOS ambient shadow — subtle and natural
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: colors.isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Apple-style blur surface — matches UIBlurEffect.Style.systemMaterial
class BlurSurface extends StatelessWidget {
  final Widget child;
  final double sigma;
  final double borderRadius;
  final bool enabled;

  const BlurSurface({
    super.key,
    required this.child,
    this.sigma = 40,
    this.borderRadius = 0,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            // Apple system material tint
            color: colors.isDark
                ? const Color(0xFF1E1E22).withValues(alpha: 0.68)
                : const Color(0xFFF9F9F9).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
