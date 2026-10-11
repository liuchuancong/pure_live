import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/tokens/breakpoints.dart';

/// Provides the UI environment to the tree.
///
/// The application installs one with the facts it alone knows (which platform,
/// whether this build is a TV build, whether blur is affordable); pages read
/// `LiveUiEnvironment.of(context)` instead of inspecting `Platform` or the
/// window themselves. [LiveLayoutBuilder] sits inside it and refines the
/// layout mode from the live window width, so a resized desktop window really
/// does change the layout while the platform facts stay put.
class LiveEnvironmentScope extends InheritedWidget {
  /// A scope providing [environment].
  const new({required this.environment, required super.child, super.key});

  /// The environment every reader below this widget sees.
  final LiveUiEnvironment environment;

  /// The environment of the nearest scope, or null outside one.
  static LiveUiEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveEnvironmentScope>()?.environment;

  /// The environment of the nearest scope.
  ///
  /// Throws when there is none: a widget that lays out differently per
  /// platform must not guess which platform it is on, because a wrong guess
  /// ships a TV layout to a phone.
  static LiveUiEnvironment of(BuildContext context) {
    final environment = maybeOf(context);
    if (environment == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No LiveEnvironmentScope found above this widget.'),
        ErrorDescription(
          'The application installs one LiveEnvironmentScope with the platform facts it knows; '
          'LiveLayoutBuilder refines it per window size. Wrap the app (or the page) before reading '
          'the environment.',
        ),
      ]);
    }
    return environment;
  }

  @override
  bool updateShouldNotify(LiveEnvironmentScope oldWidget) => environment != oldWidget.environment;
}

/// Refines the environment from the live window size and builds from it.
///
/// This is where "mobile / desktop / TV" is decided, per frame and per
/// window: the base environment supplies the platform and the capabilities,
/// the window's width supplies the layout mode and the size class, and the
/// builder receives the refined result. Rebuilding only happens when the
/// result changes — a window dragged across a breakpoint, a rotation, a TV
/// entering its TV mode — not on every pixel.
class LiveLayoutBuilder extends StatelessWidget {
  /// A layout builder.
  const new({required this.builder, this.baseEnvironment, this.breakpoints = const LiveBreakpoints(), super.key});

  /// Builds with the refined environment.
  final Widget Function(BuildContext context, LiveUiEnvironment environment) builder;

  /// The platform facts; null reads them from the nearest
  /// [LiveEnvironmentScope].
  final LiveUiEnvironment? baseEnvironment;

  /// The thresholds the window is classified against.
  final LiveBreakpoints breakpoints;

  @override
  Widget build(BuildContext context) {
    final base = baseEnvironment ?? LiveEnvironmentScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final refined = base.withWidth(width, breakpoints: breakpoints);
    final sized = refined == base
        ? refined
        : refined.withLayoutMode(
            base.platform.isTv
                // A TV keeps its layout whatever the window reports; the TV
                // layout is about viewing distance, not about width.
                ? LiveLayoutMode.tv
                : refined.layoutMode,
          );
    return LiveEnvironmentScope(environment: sized, child: builder(context, sized));
  }
}

/// Builds one of three widgets for the current layout mode.
///
/// The escape hatch for pages whose structure genuinely differs per mode —
/// a room list that is a two-pane master/detail on desktop, a grid of cards
/// on mobile and one large focus-driven row per section on TV. Pages that
/// only need *different sizes* should stay one widget and read the tokens.
class LiveAdaptiveLayout extends StatelessWidget {
  /// An adaptive layout.
  const new({required this.mobile, this.desktop, this.tv, super.key});

  /// The mobile layout; the fallback for every other mode.
  final WidgetBuilder mobile;

  /// The desktop layout; falls back to [mobile].
  final WidgetBuilder? desktop;

  /// The TV layout; falls back to [desktop], then to [mobile].
  final WidgetBuilder? tv;

  @override
  Widget build(BuildContext context) {
    return LiveLayoutBuilder(
      builder: (context, environment) {
        final builder = switch (environment.layoutMode) {
          LiveLayoutMode.mobile => mobile,
          LiveLayoutMode.desktop => desktop ?? mobile,
          LiveLayoutMode.tv => tv ?? desktop ?? mobile,
        };
        return builder(context);
      },
    );
  }
}

/// Builds from the window's size class, for pages that vary by *space*
/// rather than by device.
class LiveSizeClassBuilder extends StatelessWidget {
  /// A size-class builder.
  const new({
    required this.builder,
    this.compact,
    this.medium,
    this.expanded,
    this.large,
    this.breakpoints = const LiveBreakpoints(),
    super.key,
  });

  /// Builds with the current size class.
  final Widget Function(BuildContext context, LiveWindowSizeClass sizeClass) builder;

  /// Overrides one class; unset classes fall back to the nearest smaller one.
  final WidgetBuilder? compact;

  /// Overrides the medium class.
  final WidgetBuilder? medium;

  /// Overrides the expanded class.
  final WidgetBuilder? expanded;

  /// Overrides the large class.
  final WidgetBuilder? large;

  /// The thresholds in force.
  final LiveBreakpoints breakpoints;

  @override
  Widget build(BuildContext context) {
    final sizeClass = breakpoints.sizeClassOf(MediaQuery.sizeOf(context).width);
    final specific = switch (sizeClass) {
      LiveWindowSizeClass.compact => compact,
      LiveWindowSizeClass.medium => medium ?? compact,
      LiveWindowSizeClass.expanded => expanded ?? medium ?? compact,
      LiveWindowSizeClass.large => large ?? expanded ?? medium ?? compact,
    };
    final builder = this.builder;
    if (specific == null) {
      return builder(context, sizeClass);
    }
    return Builder(builder: specific);
  }
}
