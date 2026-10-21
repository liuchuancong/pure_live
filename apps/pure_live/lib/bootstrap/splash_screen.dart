import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, SystemUiOverlayStyle;
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

  /// How long the splash holds before [onNextPressed] runs; a tap or any
  /// key hands over sooner (the reference's own answer).
  final Duration duration;

  /// How long the icon and the text take to appear (A06.4: short enough to
  /// finish inside the page's own stay).
  static const Duration animation = Duration(milliseconds: 400);

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
  bool _left = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: SplashScreen.animation);
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));

    _controller.forward();

    if (widget.onNextPressed != null) {
      _navigationTimer = Timer(widget.duration, _leave);
    }
  }

  /// Hands over, once: the timer, a tap and a key all come through here and
  /// the first one wins (the reference's _left guard).
  void _leave() {
    if (_left) {
      return;
    }
    _left = true;
    _navigationTimer?.cancel();
    widget.onNextPressed?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.onNextPressed == null) {
      return KeyEventResult.ignored;
    }
    _leave();
    return KeyEventResult.handled;
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
    final dark = PureTheme.of(context).token.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // See-through bars with icons for the page's brightness (A06.5).
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PureScaffold(
        body: Focus(
          autofocus: widget.onNextPressed != null,
          onKeyEvent: _onKey,
          child: GestureDetector(
            key: const ValueKey('splash'),
            behavior: HitTestBehavior.opaque,
            // A06.4: a tap takes the app on at once; the splash never
            // outstays its welcome.
            onTap: widget.onNextPressed == null ? null : _leave,
            child: DecoratedBox(
              key: const ValueKey('splash-background'),
              decoration: BoxDecoration(
                color: widget.bgGradient == null && widget.bgColor != null ? widget.bgColor : null,
                gradient: widget.bgGradient ?? _defaultGradient(context, dark: dark),
              ),
              child: SizedBox.expand(
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            key: const ValueKey('splash-logo'),
                            children: [
                              if (widget.showLogo && widget.logo != null) widget.logo!,
                              if (widget.showTextLogo && widget.logoText != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(widget.logoText!, style: widget.textStyle ?? _defaultTextStyle),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (widget.showLoader) _buildLoader(),
                      const SizedBox(height: 30),
                      if (widget.nextButton != null)
                        GestureDetector(onTap: widget.onNextPressed, child: widget.nextButton),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The reference's 160-degree wash: the surface, and the primary lifted
  /// in at the lower right so the brand block sits on light ground. With a
  /// [SplashScreen.bgColor] given, that flat ground answers alone.
  Gradient _defaultGradient(BuildContext context, {required bool dark}) {
    final colors = PureTheme.of(context).colors;
    final surface = widget.bgColor ?? colors.surface;
    return LinearGradient(
      begin: const Alignment(-0.36, -1),
      end: const Alignment(0.36, 1),
      stops: const [0, 0.45, 1],
      colors: [
        surface,
        surface,
        Color.alphaBlend(colors.primary.withValues(alpha: dark ? 0.30 : 0.55), surface),
      ],
    );
  }

  TextStyle get _defaultTextStyle =>
      PureTheme.of(context).text.headline.copyWith(fontWeight: FontWeight.bold, color: _foreground);

  Widget _buildLoader() {
    switch (widget.loaderType) {
      case LoaderType.spinner:
        return PureSpinner(size: 28, color: _foreground);
      case LoaderType.dots:
        return AnimatedDots(color: _foreground);
      case LoaderType.progressBar:
        return SizedBox(
          key: const ValueKey('splash-progress'),
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
