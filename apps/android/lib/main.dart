import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/miui_theme.dart';
import 'providers/app_provider.dart';
import 'pages/schedule_page.dart';
import 'pages/tools_page.dart';
import 'pages/files_page.dart';
import 'pages/settings_page.dart';
import 'pages/blog_page.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'services/update_checker.dart';
import 'services/persistence_service.dart';
import 'services/auth_service.dart';
import 'services/reminder_service.dart';
import 'services/anti_abuse_service.dart';
import 'services/weather_service.dart';
import 'services/deepseek_service.dart';
import 'services/integrity_service.dart';
import 'services/secure_config.dart';
import 'widgets/splash_screen.dart';
import 'pages/auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal pre-splash setup: only system UI chrome (instant, no I/O)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Show splash immediately — all heavy init happens inside _SplashGate
  runApp(const ProductivityProApp());
}

/// Runs all async initialization and returns when ready.
/// Called from _SplashGate while splash animation plays.
Future<void> _initializeApp() async {
  // Phase 1: Core storage (Hive + date formatting)
  await Future.wait([
    initializeDateFormatting('zh_CN', null),
    PersistenceService.init(),
  ]);

  // Phase 2: Secure config (depends on Hive)
  await SecureConfig.init();

  // Phase 3: All services that depend on Hive, in parallel
  await Future.wait([
    AuthService().init(),
    AntiAbuseService.init(),
    WeatherService.init(),
    DeepSeekService.init(),
    IntegrityService().init(),
  ]);

  // Phase 4: Background update checker (fire-and-forget)
  UpdateChecker().init();
}

class ProductivityProApp extends StatelessWidget {
  const ProductivityProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Tempo',
            debugShowCheckedModeBanner: false,
            themeMode: provider.resolvedThemeMode,
            theme: _applyUiStyle(MiuiTheme.lightTheme, provider),
            darkTheme: _applyUiStyle(MiuiTheme.darkTheme, provider),
            home: const _SplashGate(),
          );
        },
      ),
    );
  }

  ThemeData _applyUiStyle(ThemeData base, AppProvider provider) {
    // When predictive back is enabled, our ColorOSPageRoute handles transitions
    // directly (swipe-follow-hand animation with CupertinoRouteTransitionMixin).
    // Theme transition is set to FadeForwards as a neutral fallback for any
    // non-ColorOS routes (e.g. dialogs). The actual page routes created by
    // swipeBackRoute() use ColorOSPageRoute which overrides buildTransitions.
    //
    // When disabled, use the standard Material 3 Zoom transition.
    final pageTransitions = provider.predictiveBack
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          )
        : const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          );
    return base.copyWith(
      pageTransitionsTheme: pageTransitions,
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(provider.cardRadius),
        ),
      ),
    );
  }
}

/// Splash gate: shows splash while async services initialize,
/// then transitions to privacy consent (first launch), auth, or MainShell.
///
/// Uses a Stack + AnimatedOpacity approach: the destination widget is rendered
/// BEHIND the splash, then the splash fades out. This prevents the black flash
/// that AnimatedSwitcher can cause when the new widget hasn't painted yet.
class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

enum _GatePhase { splash, consent, main }

class _SplashGateState extends State<_SplashGate>
    with SingleTickerProviderStateMixin {
  _GatePhase _phase = _GatePhase.splash;
  bool _splashVisible = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _splashVisible = false);
      }
    });
    _runInit();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _runInit() async {
    final stopwatch = Stopwatch()..start();
    await _initializeApp();
    // Initialize provider data now that services are ready
    if (mounted) {
      context.read<AppProvider>().initUsageTracking();
    }
    // Ensure minimum 1.2s splash (entrance animation is 1s)
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1200) {
      await Future.delayed(Duration(milliseconds: 1200 - elapsed));
    }
    if (!mounted) return;

    // Determine first destination
    final agreed = PersistenceService.getPrivacyAgreed();
    _GatePhase dest;
    if (!agreed) {
      dest = _GatePhase.consent;
    } else {
      dest = _GatePhase.main;
    }

    setState(() => _phase = dest);
    // Wait one frame for the destination widget to render, then fade out splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fadeCtrl.forward();
    });
  }

  void _onConsentAgreed() {
    PersistenceService.setPrivacyAgreed(true);
    if (mounted) setState(() => _phase = _GatePhase.main);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_phase != _GatePhase.splash) _buildDestination(),
        if (_splashVisible)
          RepaintBoundary(
            child: FadeTransition(
              opacity: ReverseAnimation(_fadeAnim),
              child: const SplashScreen(key: ValueKey('splash')),
            ),
          ),
      ],
    );
  }

  Widget _buildDestination() {
    switch (_phase) {
      case _GatePhase.splash:
        return const SizedBox.shrink();
      case _GatePhase.consent:
        return _PrivacyConsentScreen(
          key: const ValueKey('consent'),
          onAgreed: _onConsentAgreed,
        );
      case _GatePhase.main:
        return const MainShell(key: ValueKey('main'));
    }
  }
}

// ═══════════════════════════════════════════
// Privacy Consent — shown on first launch
// ═══════════════════════════════════════════
class _PrivacyConsentScreen extends StatelessWidget {
  final VoidCallback onAgreed;
  const _PrivacyConsentScreen({super.key, required this.onAgreed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '欢迎使用Tempo',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '专注高效的个人效率工具',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const Spacer(flex: 1),
              // Privacy summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: MiuiColors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '隐私保护承诺',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _bullet('所有数据本地存储，不会自动上传', colors),
                    const SizedBox(height: 8),
                    _bullet('云同步功能需登录后手动开启', colors),
                    const SizedBox(height: 8),
                    _bullet('不收集个人敏感信息', colors),
                    const SizedBox(height: 8),
                    _bullet('不包含第三方广告 SDK', colors),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Policy link
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  children: [
                    const TextSpan(text: '继续即表示您同意'),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _MiniPrivacyPage(colors: colors),
                          ),
                        ),
                        child: Text(
                          '《隐私政策》',
                          style: TextStyle(
                            fontSize: 12,
                            color: MiuiColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '和'),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _MiniPrivacyPage(colors: colors),
                          ),
                        ),
                        child: Text(
                          '《用户协议》',
                          style: TextStyle(
                            fontSize: 12,
                            color: MiuiColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Agree button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onAgreed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '同意并继续',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Decline button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text(
                    '不同意并退出',
                    style: TextStyle(fontSize: 14, color: colors.textTertiary),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text, AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: MiuiColors.green,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Minimal privacy policy page shown from consent screen
class _MiniPrivacyPage extends StatelessWidget {
  final AppColors colors;
  const _MiniPrivacyPage({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '隐私政策',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tempo 隐私政策',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '欢迎使用Tempo（以下简称"本应用"）。我们深知个人信息对您的重要性，并会尽全力保护您的隐私安全。\n\n'
            '1. 数据存储\n本应用的所有用户数据默认存储在您的设备本地，不会自动上传至云端。云同步功能需要您主动登录并手动开启。\n\n'
            '2. 信息收集\n本应用不收集任何个人敏感信息，不包含第三方广告 SDK。仅在您主动提交反馈时，可能附带设备型号和应用版本信息。\n\n'
            '3. 网络权限\n本应用需要网络权限用于：账户登录与注册、云端数据同步、应用版本更新检查、云工具功能（去水印、网盘直链等）。\n\n'
            '4. 数据安全\n我们采用加密传输保护您的网络通信，账户密码使用安全哈希存储，不以明文保存。\n\n'
            '5. 未成年人保护\n我们非常重视未成年人的隐私保护。如果您是未成年人，请在监护人陪同下使用本应用。\n\n'
            '6. 联系我们\n如您对本隐私政策有任何疑问，请联系：zhuj3188@gmail.com',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Welcome Auth Screen — shown after privacy consent
// User can log in, register, or skip as guest
// ═══════════════════════════════════════════
class _WelcomeAuthScreen extends StatelessWidget {
  final VoidCallback onDone;
  const _WelcomeAuthScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '登录享受完整体验',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '登录后可使用云同步、文件管理等功能',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const Spacer(flex: 2),
              // Feature highlights
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _featureRow(
                      Icons.cloud_sync_outlined,
                      '云端数据同步',
                      '多设备数据自动同步',
                      MiuiColors.blue,
                      colors,
                    ),
                    const SizedBox(height: 14),
                    _featureRow(
                      Icons.folder_outlined,
                      '文件管理',
                      '云端文件存储与分享',
                      MiuiColors.teal,
                      colors,
                    ),
                    const SizedBox(height: 14),
                    _featureRow(
                      Icons.build_outlined,
                      '云端工具',
                      '去水印、网盘直链等',
                      MiuiColors.orange,
                      colors,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AuthPage(
                          onLoginSuccess: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    );
                    if (result == true) {
                      onDone();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '登录 / 注册',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Skip as guest
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: onDone,
                  child: Text(
                    '暂不登录，游客预览',
                    style: TextStyle(fontSize: 14, color: colors.textTertiary),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    AppColors colors,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start reminder service (schedule + habit notifications)
      final provider = context.read<AppProvider>();
      ReminderService.instance.start(context, provider);

      // OPT-8: UpdateChecker.init() already schedules checkNow() after 10s,
      // so register a callback for update dialog instead of double-checking.
      UpdateChecker.onUpdateTapped = (version) {
        if (mounted) {
          final cached = UpdateChecker().cachedVersionInfo;
          if (cached != null && cached.hasUpdate) _showUpdateDialog(cached);
        }
      };
    });
  }

  @override
  void dispose() {
    ReminderService.instance.stop();
    UpdateChecker.onUpdateTapped = null;
    super.dispose();
  }

  void _showUpdateDialog(VersionInfo info) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => _UpdateDialog(info: info, colors: colors),
    );
  }

  final List<Widget> _pages = const [
    SchedulePage(),
    ToolsPage(),
    FilesPage(),
    BlogPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final colors = AppColors.of(context);
        final isFloating = provider.floatingBar;
        final isBlurred = provider.blurEffect;
        final isGlass = provider.liquidGlass;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final now = DateTime.now();
            if (_lastBackPress != null &&
                now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
              // Double tap back → exit app
              SystemNavigator.pop();
            } else {
              _lastBackPress = now;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('再按一次退出应用'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: colors.background,
            extendBody: isFloating,
            // OPT-6: IndexedStack preserves page state across tab switches
            body: IndexedStack(index: _currentIndex, children: _pages),
            bottomNavigationBar: isFloating
                ? _buildFloatingBar(
                    context,
                    colors,
                    provider,
                    isBlurred,
                    isGlass,
                  )
                : _buildAttachedBar(context, colors, provider, isBlurred),
            floatingActionButton: _currentIndex == 0
                ? FloatingActionButton(
                    onPressed: () {
                      if (!AuthService().requireLogin(context, action: '添加日程'))
                        return;
                      _showQuickAddEvent(context);
                    },
                    elevation: 0,
                    child: const Icon(Icons.add_rounded, size: 26),
                  )
                : null,
          ),
        );
      },
    );
  }

  /// Apple-style frosted glass floating tab bar
  /// Matches iOS UITabBar with .prominent style backdrop
  Widget _buildFloatingBar(
    BuildContext ctx,
    AppColors colors,
    AppProvider provider,
    bool blurred,
    bool glass,
  ) {
    // OPT-7: When blur is disabled, use 0 and skip BackdropFilter entirely
    // iOS uses ~30pt blur for system chrome material
    final sigma = glass ? 40.0 : (blurred ? 30.0 : 0.0);
    final barDecoration = BoxDecoration(
      color: glass
          ? (colors.isDark
                ? const Color(0xFF1E1E22).withValues(alpha: 0.68)
                : const Color(0xFFF9F9F9).withValues(alpha: 0.68))
          : colors.barGlassBackground,
      borderRadius: BorderRadius.circular(provider.bottomBarRadius),
      border: Border.all(
        color: colors.isDark
            ? Colors.white.withValues(alpha: glass ? 0.15 : 0.1)
            : (glass
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.04)),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: colors.isDark ? 0.5 : 0.1),
          blurRadius: 30,
          offset: const Offset(0, 8),
          spreadRadius: -5,
        ),
      ],
    );

    final barContent = Container(
      decoration: barDecoration,
      child: _buildNavItems(colors, provider),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(ctx).padding.bottom + 14,
      ),
      // OPT-7: Skip expensive BackdropFilter when blur is disabled
      child: sigma > 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(provider.bottomBarRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: barContent,
              ),
            )
          : barContent,
    );
  }

  Widget _buildAttachedBar(
    BuildContext ctx,
    AppColors colors,
    AppProvider provider,
    bool blurred,
  ) {
    if (blurred) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              // Apple-style systemChromeMaterial
              color: colors.isDark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.65)
                  : const Color(0xFFF9F9F9).withValues(alpha: 0.72),
              border: Border(
                top: BorderSide(
                  color: colors.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.33, // Apple hairline
                ),
              ),
            ),
            child: SafeArea(child: _buildNavItems(colors, provider)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(
            color: colors.divider.withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
      ),
      child: SafeArea(child: _buildNavItems(colors, provider)),
    );
  }

  Widget _buildNavItems(AppColors colors, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: '日程',
            isActive: _currentIndex == 0,
            onTap: () => _onTabTap(0),
            colors: colors,
          ),
          _NavItem(
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: '工具',
            isActive: _currentIndex == 1,
            onTap: () => _onTabTap(1),
            colors: colors,
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder_rounded,
            label: '文件',
            isActive: _currentIndex == 2,
            onTap: () => _onTabTap(2),
            colors: colors,
          ),
          _NavItem(
            icon: Icons.article_outlined,
            activeIcon: Icons.article_rounded,
            label: '博客',
            isActive: _currentIndex == 3,
            onTap: () => _onTabTap(3),
            colors: colors,
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: '设置',
            isActive: _currentIndex == 4,
            onTap: () => _onTabTap(4),
            colors: colors,
          ),
        ],
      ),
    );
  }

  void _onTabTap(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  // ═══ Quick Add Event - Swipe Chips + Templates ═══
  void _showQuickAddEvent(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _QuickAddSheet(colors: colors, provider: provider),
    );
  }
}

// ═══════════════════════════════════════════
// Quick Add Sheet - Template chips + swipe time picker
// ═══════════════════════════════════════════
class _QuickAddSheet extends StatefulWidget {
  final AppColors colors;
  final AppProvider provider;
  const _QuickAddSheet({required this.colors, required this.provider});
  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  String _title = '';
  String _desc = '';
  int _selectedTemplate = -1;
  // BUG-13 fix: create controllers in state, not in build
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _title);
    _descController = TextEditingController(text: _desc);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: 0);
  int _selectedCategory = 0;

  final _templates = [
    {
      'icon': Icons.groups_rounded,
      'label': '会议',
      'title': '团队会议',
      'desc': '讨论项目进度',
      'cat': 0,
      'color': MiuiColors.blue,
    },
    {
      'icon': Icons.fitness_center_rounded,
      'label': '锻炼',
      'title': '健身训练',
      'desc': '力量 + 有氧',
      'cat': 1,
      'color': MiuiColors.green,
    },
    {
      'icon': Icons.menu_book_rounded,
      'label': '阅读',
      'title': '阅读时间',
      'desc': '享受阅读',
      'cat': 2,
      'color': MiuiColors.purple,
    },
    {
      'icon': Icons.restaurant_rounded,
      'label': '约饭',
      'title': '朋友聚餐',
      'desc': '',
      'cat': 3,
      'color': MiuiColors.orange,
    },
    {
      'icon': Icons.code_rounded,
      'label': '编码',
      'title': '写代码',
      'desc': '专注开发',
      'cat': 0,
      'color': MiuiColors.teal,
    },
    {
      'icon': Icons.self_improvement_rounded,
      'label': '冥想',
      'title': '正念冥想',
      'desc': '15 分钟呼吸练习',
      'cat': 1,
      'color': MiuiColors.pink,
    },
    {
      'icon': Icons.shopping_bag_rounded,
      'label': '购物',
      'title': '购物',
      'desc': '',
      'cat': 4,
      'color': MiuiColors.yellow,
    },
    {
      'icon': Icons.call_rounded,
      'label': '电话',
      'title': '电话会议',
      'desc': '远程沟通',
      'cat': 0,
      'color': MiuiColors.red,
    },
  ];

  final _categories = [
    {'label': '工作', 'color': MiuiColors.blue},
    {'label': '健康', 'color': MiuiColors.green},
    {'label': '学习', 'color': MiuiColors.purple},
    {'label': '社交', 'color': MiuiColors.orange},
    {'label': '生活', 'color': MiuiColors.teal},
    {'label': '休闲', 'color': MiuiColors.yellow},
  ];

  void _selectTemplate(int i) {
    final t = _templates[i];
    _title = t['title'] as String;
    _desc = t['desc'] as String;
    // BUG-13: update controller text when selecting template
    _titleController.text = _title;
    _descController.text = _desc;
    setState(() {
      _selectedTemplate = i;
      _selectedCategory = t['cat'] as int;
    });
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: widget.colors.card,
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addEvent() {
    if (_title.isEmpty) return;
    final cat = _categories[_selectedCategory];
    widget.provider.addEvent(
      ScheduleEvent(
        id: 'new_${DateTime.now().millisecondsSinceEpoch}',
        title: _title,
        description: _desc,
        time:
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime:
            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        category: cat['label'] as String,
        accentColor: cat['color'] as Color,
      ),
    );
    Navigator.pop(context);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Text(
                '添加日程',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: c.textPrimary,
                ),
              ),
            ),

            // Quick templates - horizontal scrollable chips
            SizedBox(
              height: 80,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final t = _templates[i];
                  final selected = _selectedTemplate == i;
                  final color = t['color'] as Color;
                  return GestureDetector(
                    onTap: () => _selectTemplate(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 70,
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.15)
                            : c.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: selected
                            ? Border.all(color: color, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t['icon'] as IconData,
                            color: selected ? color : c.textSecondary,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? color : c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Title input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '日程标题',
                    hintStyle: TextStyle(
                      color: c.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.edit_rounded,
                      color: c.textTertiary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  controller: _titleController,
                  onChanged: (v) => _title = v,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '描述（可选）',
                    hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.notes_rounded,
                      color: c.textTertiary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  controller: _descController,
                  onChanged: (v) => _desc = v,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time pickers - tap to select
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: MiuiColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtTime(_startTime),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time_filled_rounded,
                              size: 18,
                              color: MiuiColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtTime(_endTime),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category chips - swipable
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final color = cat['color'] as Color;
                  final selected = _selectedCategory == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: selected ? color : c.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : c.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Add button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _addEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '添加日程',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _handle(AppColors c) => Container(
    width: 36,
    height: 5,
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    decoration: BoxDecoration(
      color: c.textTertiary.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final AppColors colors;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? MiuiColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 21,
                color: isActive ? MiuiColors.primary : colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? MiuiColors.primary : colors.textSecondary,
                letterSpacing: 0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Update Dialog — Pure Incremental Update v4
// ═══════════════════════════════════════════
class _UpdateDialog extends StatefulWidget {
  final VersionInfo info;
  final AppColors colors;
  const _UpdateDialog({required this.info, required this.colors});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String _statusText = '';
  bool _downloadComplete = false;
  bool _cancelled = false;
  double _speed = 0;
  int _speedTrackStart = 0;
  int _speedTrackBytes = 0;
  String? _completedApkPath;

  String get _speedText {
    if (_speed <= 0) return '';
    if (_speed > 1024 * 1024)
      return '${(_speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(_speed / 1024).toStringAsFixed(0)} KB/s';
  }

  void _trackSpeed(int received) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_speedTrackStart == 0) {
      _speedTrackStart = now;
      _speedTrackBytes = received;
      return;
    }
    final elapsed = (now - _speedTrackStart) / 1000.0;
    if (elapsed < 0.5) return;
    _speed = (received - _speedTrackBytes) / elapsed;
    _speedTrackStart = now;
    _speedTrackBytes = received;
  }

  Future<void> _startDownload() async {
    if (!widget.info.patchAvailable) {
      if (mounted) {
        setState(() {
          _statusText = '暂无增量包，请连接Wi-Fi等待自动更新';
        });
      }
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
      _statusText = '准备增量更新...';
      _cancelled = false;
      _speed = 0;
      _speedTrackStart = 0;
      _speedTrackBytes = 0;
      _completedApkPath = null;
    });

    if (!Platform.isAndroid) {
      setState(() {
        _downloading = false;
        _statusText = '请在 Android 设备上更新';
      });
      return;
    }

    final savePath = await UpdateChecker.getApkSavePath();
    final currentApkPath = await ApiService.getCurrentApkPath();
    if (currentApkPath == null) {
      setState(() {
        _downloading = false;
        _statusText = '无法获取当前APK路径';
      });
      return;
    }

    try {
      final result = await ApiService().downloadAndApplyPatch(
        info: widget.info,
        currentApkPath: currentApkPath,
        savePath: savePath,
        onStage: (stage) {
          if (!mounted || _cancelled) return;
          switch (stage) {
            case 'downloading':
              setState(() {
                _statusText = '下载增量包...';
              });
              break;
            case 'patching':
              setState(() {
                _statusText = '合并更新中...';
                _progress = 0.9;
              });
              break;
            case 'verifying':
              setState(() {
                _statusText = '校验文件...';
                _progress = 0.95;
              });
              break;
          }
        },
        onProgress: (received, total) {
          if (!mounted || _cancelled) return;
          _trackSpeed(received);
          final effectiveTotal = widget.info.patchSize > 0
              ? widget.info.patchSize
              : total;
          final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
          if (effectiveTotal > 0 && effectiveTotal >= received) {
            final pct = received / effectiveTotal;
            final totalMB = (effectiveTotal / (1024 * 1024)).toStringAsFixed(1);
            setState(() {
              _progress = pct * 0.85;
              _statusText =
                  '增量下载 $receivedMB / $totalMB MB${_speedText.isNotEmpty ? '  $_speedText' : ''}';
            });
          } else {
            setState(() {
              _progress = -1;
              _statusText = '增量下载 $receivedMB MB...';
            });
          }
        },
      );

      if (_cancelled) {
        setState(() {
          _downloading = false;
          _statusText = '已取消';
        });
        return;
      }

      _completedApkPath = result;
      setState(() {
        _downloadComplete = true;
        _progress = 1.0;
        _statusText = '更新完成，正在安装...';
      });
      final installed = await ApiService.installApk(result);
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = installed ? '安装已启动，请确认安装' : '请点击下方按钮安装';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = '增量更新失败: $e';
        });
      }
    }
  }

  Future<void> _triggerInstall() async {
    if (_completedApkPath == null) return;
    setState(() {
      _statusText = '正在启动安装...';
    });
    final installed = await ApiService.installApk(_completedApkPath!);
    if (mounted) {
      setState(() {
        _statusText = installed ? '安装已启动，请确认安装' : '启动安装失败，请手动安装';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final info = widget.info;

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MiuiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: MiuiColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '发现新版本',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MiuiColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${info.latestVersion} (Build ${info.latestBuild})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MiuiColors.primary,
                  ),
                ),
              ),
              if (info.apkSizeFormatted.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  info.apkSizeFormatted,
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '更新内容',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.releaseNotes,
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
          ),
          if (info.forceUpdate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MiuiColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, size: 16, color: MiuiColors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此版本为强制更新',
                      style: TextStyle(
                        fontSize: 12,
                        color: MiuiColors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Download progress section
          if (_downloading) ...[
            const SizedBox(height: 20),
            if (!_downloadComplete)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: MiuiColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: MiuiColors.green),
                    const SizedBox(width: 4),
                    Text(
                      '\u589e\u91cf\u66f4\u65b0',
                      style: TextStyle(
                        fontSize: 11,
                        color: MiuiColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _downloadComplete
                    ? 1.0
                    : (_progress < 0 ? null : _progress),
                minHeight: 6,
                backgroundColor: MiuiColors.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(
                  _downloadComplete ? MiuiColors.green : MiuiColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_downloadComplete)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MiuiColors.primary,
                    ),
                  ),
                if (!_downloadComplete) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _downloadComplete
                          ? MiuiColors.green
                          : c.textSecondary,
                    ),
                  ),
                ),
                if (!_downloadComplete && _progress >= 0)
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MiuiColors.primary,
                    ),
                  ),
              ],
            ),
          ],
          if (!_downloading && _statusText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _statusText,
              style: TextStyle(fontSize: 12, color: MiuiColors.red),
            ),
          ],
        ],
      ),
      actions: [
        // Cancel button during download
        if (_downloading && !_downloadComplete)
          TextButton(
            onPressed: () {
              _cancelled = true;
              setState(() {
                _statusText = '正在取消...';
              });
            },
            child: Text('取消下载', style: TextStyle(color: MiuiColors.red)),
          ),
        if (!info.forceUpdate && !_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍后再说', style: TextStyle(color: c.textSecondary)),
          ),
        // Download complete: show install button
        if (!_downloading && _downloadComplete && _completedApkPath != null)
          ElevatedButton.icon(
            onPressed: _triggerInstall,
            icon: const Icon(Icons.install_mobile_rounded, size: 18),
            label: const Text('安装更新'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MiuiColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        // Not started or failed: show start/retry button
        if (!_downloading && !_downloadComplete)
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: MiuiColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(_statusText.contains('失败') ? '重试' : '立即更新'),
          ),
      ],
    );
  }
}
