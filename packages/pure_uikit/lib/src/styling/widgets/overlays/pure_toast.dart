import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The semantic kinds of a toast, mapped to the theme's status colours.
enum PureToastType {
  /// Informational.
  info,

  /// Successful.
  success,

  /// Warning.
  warning,

  /// Error.
  error,
}

/// A brief, self-dismissing status message — Ant's `message`.
///
/// The placement, the fade-and-slide and the removal timer are the core's job;
/// the plate is painted here from the tokens — WinUI's info bar with its
/// accent rule. The colours, radii, shadows, motion and text all come from
/// the tokens, so a re-skin and a dark switch still come out right — a
/// transient message is exactly the surface no anchor library drops into a
/// `PureConfigProvider` that sits above the [Navigator], which is why it is
/// painted here rather than borrowed. Nothing here needs a `Scaffold`: the
/// message goes to the root [Overlay], so a toast fired from a route, a dialog
/// or a second desktop window still finds its way to the top of the screen.
abstract final class PureToast {
  /// Shows [message] for [duration], then removes it.
  ///
  /// [type] picks the status colour the plate's mark is drawn in — [accent]
  /// overrides it, [icon] the glyph. A context with no [Overlay] above it (a
  /// bare test harness, a window still building) is not an error worth crashing
  /// over: the call is dropped, since the message had nowhere to be drawn anyway.
  static void show(
    BuildContext context,
    String message, {
    PureToastType type = PureToastType.info,
    IconData? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final theme = PureTheme.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final spec = _ToastSpec(message: message, type: type, icon: icon, accent: accent, duration: duration);
    // The visual is resolved on the caller's side of the route, because the
    // provider sits above the Navigator and is out of reach once the plate is on
    // the overlay — the same reason the menu captures its theme.
    final visual = _ToastVisual.fluent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _ToastOverlay(theme: theme, visual: visual, spec: spec, lifetime: duration, onFinished: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

/// The plate a message is drawn on: the surface (the info bar's accent rule
/// down its leading edge), the glyph set, the colour of the text, and the
/// slide the message arrives through.
@immutable
final class _ToastVisual {
  const new({
    required this.plate,
    required this.padding,
    required this.gap,
    required this.iconSize,
    required this.maxWidth,
    required this.glyph,
    required this.iconTint,
    required this.content,
    required this.badge,
    required this.beginOffset,
    required this.curve,
  });

  /// Windows's info bar: the bordered card at Fluent's corner with the status
  /// colour ruled down its leading edge — the mark every WinUI notification and
  /// info bar carries.
  factory fluent() => _ToastVisual(
    plate: (theme, accent, body) =>
        _ruled(theme, body, accent, radius: 4, rule: 3, border: theme.colors.borderSecondary),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    gap: 8,
    iconSize: 16,
    maxWidth: 460,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.24),
    curve: Curves.easeOutCubic,
  );

  /// Wraps the row in whatever the language puts around it: the fill, the blur,
  /// the border, the rule, the shadow, the plate's own inset.
  final Widget Function(PureTheme theme, Color accent, Widget body) plate;

  /// The inset around a message's glyph and text.
  final EdgeInsets padding;

  /// The gap between the glyph and the text.
  final double gap;

  /// The size of the glyph.
  final double iconSize;

  /// The widest the plate gets before the message wraps onto a second line.
  final double maxWidth;

  /// The glyph set the language's own platform draws these marks with.
  final IconData Function(PureToastType type) glyph;

  /// The colour of the glyph (and of the badge behind it, where there is one).
  final Color Function(PureTheme theme, Color accent) iconTint;

  /// The colour of the message on this plate.
  final Color Function(PureTheme theme) content;

  /// Whether the glyph sits in a round badge of the accent colour in front of
  /// the message; the info bar draws the bare glyph.
  final bool badge;

  /// The offset the plate slides down from, and the curve it arrives on.
  final Offset beginOffset;
  final Curve curve;
}

/// How the plate's leading mark is drawn: the accent rule.
///
/// A rule needs the plate clipped, because a non-uniform border cannot carry a
/// rounded corner — so the bar is a plain child behind a [ClipRRect] instead.
Widget _ruled(
  PureTheme theme,
  Widget body,
  Color accent, {
  required double radius,
  required double rule,
  required Color border,
}) => ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colors.surfaceElevated,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: _elevation(theme, 8),
    ),
    child: Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(left: rule),
          child: body,
        ),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          width: rule,
          child: ColoredBox(color: accent),
        ),
      ],
    ),
  ),
);

/// The elevation shadow a bordered plate floats on.
List<BoxShadow> _elevation(PureTheme theme, double blur) => [
  BoxShadow(
    color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.5 : 0.2),
    blurRadius: blur,
    offset: Offset(0, blur / 4),
  ),
];

/// The glyph set Windows draws these marks with.
IconData _sdkGlyph(PureToastType type) => switch (type) {
  PureToastType.info => Icons.info_outline,
  PureToastType.success => Icons.check_circle_outline,
  PureToastType.warning => Icons.warning_amber_rounded,
  PureToastType.error => Icons.error_outline,
};

/// The overlay's own slice of the screen: the placement, the entrance, the timer
/// that ends the message and the semantics that reads it aloud. The plate inside
/// it is the active language's.
class _ToastOverlay extends StatefulWidget {
  const new({
    required this.theme,
    required this.visual,
    required this.spec,
    required this.lifetime,
    required this.onFinished,
  });

  final PureTheme theme;
  final _ToastVisual visual;
  final _ToastSpec spec;
  final Duration lifetime;
  final VoidCallback onFinished;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.theme.duration);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: widget.visual.curve);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.visual.beginOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: widget.visual.curve));
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.lifetime, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) {
      return;
    }
    setState(() => _dismissing = true);
    await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The status colour the kind maps to, unless the caller overrode it.
  Color get _accent =>
      widget.spec.accent ??
      switch (widget.spec.type) {
        PureToastType.info => widget.theme.colors.info,
        PureToastType.success => widget.theme.colors.success,
        PureToastType.warning => widget.theme.colors.warning,
        PureToastType.error => widget.theme.colors.error,
      };

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    // A destructive word has to reach a screen reader the moment it lands, the
    // way every platform's own notification channel does; a passing note waits.
    final role = widget.spec.type == PureToastType.error || widget.spec.type == PureToastType.warning
        ? SemanticsRole.alert
        : SemanticsRole.status;
    final body = theme.text.body.copyWith(color: visual.content(theme));
    // The kind's mark is the default; a caller that names an icon gets its own.
    final mark = Icon(
      widget.spec.icon ?? visual.glyph(widget.spec.type),
      size: visual.iconSize,
      color: visual.iconTint(theme, _accent),
    );

    final plate = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: visual.maxWidth),
      child: visual.plate(
        theme,
        _accent,
        Padding(
          padding: visual.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visual.badge)
                Container(
                  width: visual.iconSize + theme.token.scale.sizes.xs,
                  height: visual.iconSize + theme.token.scale.sizes.xs,
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: mark,
                )
              else
                mark,
              SizedBox(width: visual.gap),
              Flexible(child: Text(widget.spec.message, style: body)),
            ],
          ),
        ),
      ),
    );

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.lg),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Semantics(
                  // The branch a language draws is its identity in tests and
                  // diagnostics.
                  key: ValueKey('PureToast.${theme.config.language.name}'),
                  role: role,
                  container: true,
                  label: widget.spec.message,
                  child: plate,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The toast's own record of what to show — an internal detail since the
/// adapter layer went away; nothing outside this file constructs it.
final class _ToastSpec {
  const new({required this.message, required this.type, required this.duration, this.icon, this.accent});

  final String message;
  final PureToastType type;
  final IconData? icon;
  final Color? accent;
  final Duration duration;
}
