import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Creates a page route with ColorOS-style swipe-follow-hand animation.
///
/// When [AppProvider.predictiveBack] is true, returns a [ColorOSPageRoute]
/// that provides:
///   1. **Real-time finger tracking**: page slides with your finger
///   2. **Previous page preview**: previous page visible in real-time during swipe
///   3. **Cancellable**: drag back to cancel, the animation reverses smoothly
///   4. **Dual-edge**: works from both left and right screen edges
///   5. **Seamless visual continuity**: rounded corners + scale + dimming
///
/// This leverages Flutter's [CupertinoRouteTransitionMixin] gesture system
/// (proven drag-to-dismiss math) with ColorOS-style visual rendering.
///
/// When false, uses standard Material page transitions.
PageRoute<T> swipeBackRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool? maintainState,
}) {
  final predictiveBack = context.read<AppProvider>().predictiveBack;
  if (predictiveBack) {
    return ColorOSPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState ?? true,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState ?? true,
  );
}

/// A page route that mimics ColorOS 16's "侧滑跟手动画" (swipe-follow animation).
///
/// Uses [CupertinoRouteTransitionMixin] for gesture handling (edge detection,
/// drag tracking, velocity-based commit/cancel), but replaces the iOS visual
/// transition with a ColorOS-inspired one:
///
/// - Current page: slides horizontally with finger, gains rounded corners + shadow
/// - Previous page: scales up from 0.92 -> 1.0, parallax shift, dim overlay fades out
class ColorOSPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  final WidgetBuilder builder;

  ColorOSPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    this.maintainState = true,
  });

  @override
  final bool maintainState;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  String? get title => null;

  @override
  bool get popGestureEnabled => !fullscreenDialog && super.popGestureEnabled;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ColorOSPageTransition(
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
      linearTransition: popGestureInProgress,
      child: child,
    );
  }

  // Allow the previous route to also animate (scale down) when this one enters.
  // Only apply secondary animation (scale/dim/slide) when transitioning to
  // another *non-dialog* PageRoute.
  //
  // Guards against:
  //   * showDialog            -> DialogRoute (PopupRoute — explicitly rejected)
  //   * showModalBottomSheet  -> ModalBottomSheetRoute (PopupRoute)
  //   * showMenu / showCupertinoModalPopup / showBottomSheet -> PopupRoute
  //   * RawDialogRoute        -> also a PopupRoute subclass
  //   * Any fullscreenDialog  -> don't want the underlying page to shrink
  //
  // Without this guard, the previous page could briefly scale down to 0.92
  // and flash a solid ColoredBox (scaffold background color) in place of the
  // real content — which looks like a black flash in dark mode.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Explicit blocklist: PopupRoutes (dialogs, bottom sheets, menus)
    if (nextRoute is PopupRoute) return false;
    // Only animate under other PageRoutes
    if (nextRoute is! PageRoute) return false;
    if (nextRoute.fullscreenDialog) return false;
    return true;
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    if (previousRoute is PopupRoute) return false;
    if (previousRoute is! PageRoute) return false;
    if (fullscreenDialog) return false;
    return true;
  }
}

/// The ColorOS-style page transition widget.
///
/// Uses a [StatefulWidget] to properly manage [CurvedAnimation] lifecycle and
/// listen to BOTH [primaryAnimation] and [secondaryAnimation].
///
/// Critical: the previous page's [secondaryAnimation] must be listened to so
/// it rebuilds in real-time as the user drags the current page away.
class ColorOSPageTransition extends StatefulWidget {
  final Animation<double> primaryAnimation;
  final Animation<double> secondaryAnimation;
  final bool linearTransition;
  final Widget child;

  const ColorOSPageTransition({
    super.key,
    required this.primaryAnimation,
    required this.secondaryAnimation,
    required this.linearTransition,
    required this.child,
  });

  @override
  State<ColorOSPageTransition> createState() => _ColorOSPageTransitionState();
}

class _ColorOSPageTransitionState extends State<ColorOSPageTransition> {
  // ── ColorOS design parameters ──
  static const double _kPrevPageScale = 0.92;
  static const double _kPrevPageDim = 0.08;
  static const double _kCornerRadius = 20.0;
  static const double _kShadowSigma = 12.0;
  static const double _kParallaxFactor = 0.3;

  // Animations for the current (primary) page
  late Animation<Offset> _primarySlide;
  late Animation<double> _primaryRadius;

  // Animations for the previous (secondary) page
  late Animation<Offset> _secondarySlide;
  late Animation<double> _secondaryScale;
  late Animation<double> _secondaryDim;
  late Animation<double> _secondaryRadius;

  // Managed CurvedAnimations (must be disposed)
  CurvedAnimation? _primaryCurve;
  CurvedAnimation? _secondaryCurve;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didUpdateWidget(covariant ColorOSPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryAnimation != widget.primaryAnimation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation ||
        oldWidget.linearTransition != widget.linearTransition) {
      _disposeCurves();
      _setupAnimations();
    }
  }

  @override
  void dispose() {
    _disposeCurves();
    super.dispose();
  }

  void _disposeCurves() {
    _primaryCurve?.dispose();
    _secondaryCurve?.dispose();
    _primaryCurve = null;
    _secondaryCurve = null;
  }

  void _setupAnimations() {
    // Primary page curve (linear during gesture for finger tracking)
    if (!widget.linearTransition) {
      _primaryCurve = CurvedAnimation(
        parent: widget.primaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      _secondaryCurve = CurvedAnimation(
        parent: widget.secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
    }

    final Animation<double> primaryDriver =
        _primaryCurve ?? widget.primaryAnimation;
    final Animation<double> secondaryDriver =
        _secondaryCurve ?? widget.secondaryAnimation;

    // Current page: slides from right to center, corners round during transition
    _primarySlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(primaryDriver);

    _primaryRadius = Tween<double>(
      begin: _kCornerRadius,
      end: 0.0,
    ).animate(primaryDriver);

    // Previous page: parallax shift, scale, dim, rounded corners
    _secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-_kParallaxFactor, 0.0),
    ).animate(secondaryDriver);

    _secondaryScale = Tween<double>(
      begin: 1.0,
      end: _kPrevPageScale,
    ).animate(secondaryDriver);

    _secondaryDim = Tween<double>(
      begin: 0.0,
      end: _kPrevPageDim,
    ).animate(secondaryDriver);

    _secondaryRadius = Tween<double>(
      begin: 0.0,
      end: _kCornerRadius,
    ).animate(secondaryDriver);
  }

  // Threshold below which we consider the secondary animation "inactive" and
  // skip the scale/dim/backdrop treatment entirely. Without this guard, even
  // microscopic floating-point jitter (e.g. 1e-4) from showDialog /
  // showModalBottomSheet side effects would make us render the "previous page"
  // branch for a single frame, flashing a solid scaffold-background ColoredBox
  // over the real content. In dark mode this appears as a black flash.
  static const double _kSecondaryActiveThreshold = 0.01;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to BOTH animations so we rebuild for both primary and secondary changes.
    // This is critical: when this widget wraps the PREVIOUS page, only
    // secondaryAnimation changes during a gesture — we must rebuild for it.
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.primaryAnimation,
        widget.secondaryAnimation,
      ]),
      builder: (context, _) {
        final double secondaryValue = widget.secondaryAnimation.value;
        final double primaryValue = widget.primaryAnimation.value;

        // ── When this is the PREVIOUS (background) page ──
        // secondaryAnimation > threshold means another *page route* is on top.
        // The threshold (0.01) is important: showDialog / showModalBottomSheet
        // / showMenu spawn PopupRoutes, and although ColorOSPageRoute's
        // canTransitionTo() rejects them, the Flutter framework still briefly
        // pulses secondaryAnimation in some edge cases (e.g. when the current
        // route is popping while a dialog is being shown). Ignoring tiny
        // values prevents a single-frame ColoredBox overlay from leaking
        // through as a black flash in dark mode.
        if (secondaryValue > _kSecondaryActiveThreshold) {
          // Protective backdrop: fills the area exposed when the page scales
          // down to 0.92. Without this, the gap behind Scaffold shows the
          // default black of Stack, causing a black flash.
          final Color backdrop = Theme.of(context).scaffoldBackgroundColor;
          return ColoredBox(
            color: backdrop,
            child: SlideTransition(
              position: _secondarySlide,
              transformHitTests: false,
              child: Transform.scale(
                scale: _secondaryScale.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_secondaryRadius.value),
                  child: Stack(
                    children: [
                      // Inner backdrop inside the clipped region too, so rounded
                      // corners never reveal black while content is repainting.
                      Positioned.fill(child: ColoredBox(color: backdrop)),
                      widget.child,
                      // Dimming overlay that fades as user drags page away.
                      // In light mode use a very subtle black overlay; in dark
                      // mode use a *lighter* overlay (muted white) so the
                      // backgrounded page doesn't crush to pure black.
                      if (_secondaryDim.value > 0.001)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(
                                    alpha:
                                        _secondaryDim.value *
                                        (isDark ? 0.3 : 1.0),
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // ── When this is the CURRENT (foreground) page ──
        // primaryAnimation drives slide, corner radius, and shadow
        return SlideTransition(
          position: _primarySlide,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_primaryRadius.value),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: primaryValue < 0.99
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.18 * (1.0 - primaryValue),
                          ),
                          blurRadius: _kShadowSigma,
                          offset: const Offset(-4, 0),
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
