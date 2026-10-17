import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The loader the splash draws under the brand.
enum LoaderType {
  /// A ring spinning under the brand.
  spinner,

  /// Three dots pulsing together.
  dots,

  /// A thin bar filling along its track.
  progressBar,
}

/// The start-up splash (3.x `SplashScreen`): the brand fading and scaling in
/// over a brightness-adaptive gradient, a loader underneath, then the launch
/// hands over through [SplashScreen.onNextPressed] once [duration] is spent.
///
/// This app boots before the first frame — the composition root opens the
/// storage, the window and the provider overrides while the splash is still
/// the only thing on screen — so the splash owns no init steps: branding and
/// the bounded route-on timer only. With no [bgColor] and no [bgGradient]
/// the gradient follows the ambient brightness, which the reference wired
/// per-launch from its own theme read.
class SplashScreen extends StatefulWidget {
  /// The splash screen.
  const new({
    super.key,
    this.bgColor,
    this.bgGradient,
    this.logo,
    this.logoText,
    this.showLogo = true,
    this.showTextLogo = false,
    this.showLoader = true,
    this.loaderType = LoaderType.spinner,
    this.onNextPressed,
    this.nextButton,
    this.duration = const Duration(seconds: 3),
    this.textStyle,
  });

  /// A flat background, used when [bgGradient] is null.
  final Color? bgColor;

  /// The background gradient; wins over [bgColor].
  final Gradient? bgGradient;

  /// The brand block above the text logo.
  final Widget? logo;

  /// The text logo under [logo].
  final String? logoText;

  /// Whether [logo] shows.
  final bool showLogo;

  /// Whether [logoText] shows.
  final bool showTextLogo;

  /// Whether a loader shows.
  final bool showLoader;

  /// Which loader shows.
  final LoaderType loaderType;

  /// Runs once [duration] has passed — the route-on hook.
  final VoidCallback? onNextPressed;

  /// An explicit affordance for [onNextPressed]; without it the timer alone
  /// moves the app on.
  final Widget? nextButton;

  /// How long the splash holds before [onNextPressed] runs.
  final Duration duration;

  /// The text logo's style; the theme's headline when null.
  final TextStyle? textStyle;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    if (widget.onNextPressed != null) {
      _navigationTimer = Timer(widget.duration, () {
        if (mounted) {
          widget.onNextPressed!();
        }
      });
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The foreground the splash paints with: the text style's own colour when
  /// one is given, the theme's on-surface ink otherwise — the adaptive
  /// default pairs with the adaptive gradient.
  Color get _foreground {
    final color = widget.textStyle?.color;
    if (color != null) {
      return color;
    }
    return PureTheme.of(context).colors.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: widget.bgGradient == null ? widget.bgColor ?? _fallbackBackground : null,
          gradient: widget.bgGradient,
        ),
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showLogo && widget.logo != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: widget.logo),
              ),
            if (widget.showTextLogo && widget.logoText != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(widget.logoText!, style: widget.textStyle ?? _defaultTextStyle),
                ),
              ),
            const SizedBox(height: 30),
            if (widget.showLoader) _buildLoader(),
            const SizedBox(height: 30),
            if (widget.nextButton != null) GestureDetector(onTap: widget.onNextPressed, child: widget.nextButton),
          ],
        ),
      ),
    );
  }

  TextStyle get _defaultTextStyle =>
      PureTheme.of(context).text.headline.copyWith(fontWeight: FontWeight.bold, color: _foreground);

  /// The gradient-less background, from the ambient brightness.
  Color get _fallbackBackground =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1B2A) : const Color(0xFFE0F7FA);

  Widget _buildLoader() {
    switch (widget.loaderType) {
      case LoaderType.spinner:
        return PureSpinner(size: 28, color: _foreground);
      case LoaderType.dots:
        return AnimatedDots(color: _foreground);
      case LoaderType.progressBar:
        return SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: _foreground.withValues(alpha: 0.25),
            color: _foreground,
          ),
        );
    }
  }
}

/// Three dots pulsing together — the reference's `AnimatedDots`.
class AnimatedDots extends StatefulWidget {
  /// The dots loader.
  const new({super.key, this.color = Colors.white, this.dotCount = 3});

  /// The dots' colour.
  final Color color;

  /// How many dots pulse.
  final int dotCount;

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.dotCount, (index) {
        return FadeTransition(
          opacity: _animation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.circle, size: 12, color: widget.color),
          ),
        );
      }),
    );
  }
}
