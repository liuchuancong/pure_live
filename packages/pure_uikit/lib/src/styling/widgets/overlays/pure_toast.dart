import 'dart:async';
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
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
/// what the active design language decides is the plate itself, painted here one
/// shape per language from the tokens — the M3 snackbar's inverse plate under
/// material, the iOS HUD's blurred panel under cupertino, the vibrancy HUD sheet
/// under macOS, WinUI's info bar with its accent rule under fluent, Ubuntu's
/// rounded notification with its round glyph badge under Yaru, the shadcn toast
/// under ForUI, the frosted pill under glass, the extruded plate under
/// neumorphic and the crisp bordered bar under wind. The colours, radii,
/// shadows, blur, motion and text all come from the tokens, so a language
/// re-skin and a dark switch still come out right — a transient message is
/// exactly the surface no anchor library drops into a `PureConfigProvider` that
/// sits above the [Navigator], which is why it is painted here rather than
/// borrowed. Nothing here needs a `Scaffold`: the message goes to the root
/// [Overlay], so a toast fired from a route, a dialog or a second desktop window
/// still finds its way to the top of the screen.
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
    final visual = _toastVisual(theme);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _ToastOverlay(theme: theme, visual: visual, spec: spec, lifetime: duration, onFinished: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

/// The plate a message is drawn on: the surface, the mark that names the
/// language (an accent rule down its leading edge, a round glyph badge), the
/// glyph set its platform uses, the colour of its text, and the slide the
/// message arrives through.
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

  /// Material 3's snackbar: the inverse plate — a dark pill in a light theme, an
  /// elevated one in a dark theme — with the status colour kept for the glyph
  /// alone, as M3's snack does.
  factory material() => _ToastVisual(
    plate: (theme, accent, body) => _card(theme, body, radius: 6, fill: theme.colors.bgSpotlight, elevation: 6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    gap: 10,
    iconSize: 18,
    maxWidth: 480,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.isDark ? theme.colors.text : theme.colors.white,
    badge: false,
    beginOffset: const Offset(0, -0.3),
    curve: Curves.easeOutCubic,
  );

  /// iOS's HUD: what iOS itself puts up over a page for a transient word — a
  /// blurred rounded panel, its glyph in the status colour, its text in the
  /// plain role over the vibrancy.
  factory cupertino() => _ToastVisual(
    plate: (theme, accent, body) => _frost(
      theme,
      body,
      radius: 14,
      fill: theme.isDark ? const Color(0xE62C2C2E) : const Color(0xE6FFFFFF),
      sigma: 20,
      edge: theme.colors.borderSecondary.withValues(alpha: 0.4),
      elevation: 12,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    gap: 8,
    iconSize: 17,
    maxWidth: 340,
    glyph: _cupertinoGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.2),
    curve: Curves.easeOut,
  );

  /// macOS's HUD sheet: the same floating panel the system draws its progress
  /// HUD on — vibrancy at the control radius, a hair edge, a dense row.
  factory macos() => _ToastVisual(
    plate: (theme, accent, body) => _frost(
      theme,
      body,
      radius: 12,
      fill: theme.isDark ? const Color(0xE83A3A3C) : const Color(0xE8FFFFFF),
      sigma: 30,
      edge: theme.colors.borderSecondary.withValues(alpha: 0.45),
      elevation: 14,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    gap: 8,
    iconSize: 16,
    maxWidth: 380,
    glyph: _macosGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.25),
    curve: Curves.easeOut,
  );

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

  /// Ubuntu's notification: a rounded card whose message arrives with its glyph
  /// in the round badge the Yaru shell puts in front of everything, and the
  /// status colour as the tint of that badge rather than a rule.
  factory yaru() => _ToastVisual(
    plate: (theme, accent, body) => _card(
      theme,
      body,
      radius: PureRadii.md,
      fill: theme.colors.surfaceElevated,
      border: theme.colors.borderSecondary,
      elevation: 8,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    gap: 10,
    iconSize: 16,
    maxWidth: 420,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: true,
    beginOffset: const Offset(0, -0.2),
    curve: Curves.easeOut,
  );

  /// ForUI's shadcn toast: the bordered card with a ring of shadow the alert
  /// sheet uses, its leading glyph in the status colour.
  factory forui() => _ToastVisual(
    plate: (theme, accent, body) => _card(
      theme,
      body,
      radius: theme.token.scale.radii.lg,
      fill: theme.colors.surfaceElevated,
      border: theme.colors.border,
      elevation: 12,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    gap: 10,
    iconSize: 18,
    maxWidth: 420,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.28),
    curve: Curves.easeOutCubic,
  );

  /// The glass language: a frosted pill — a real backdrop blur over a barely
  /// there fill when the device can afford it, a plain translucent panel when it
  /// cannot — with a lit hair edge.
  factory glass() => _ToastVisual(
    plate: (theme, accent, body) => _frost(
      theme,
      body,
      radius: PureRadii.pill,
      fill: theme.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.5),
      sigma: 18,
      edge: theme.isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.6),
      elevation: 10,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    gap: 10,
    iconSize: 18,
    maxWidth: 420,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.22),
    curve: Curves.easeOutCubic,
  );

  /// The neumorphic language: a plate raised off the page it lands on — light
  /// from the top left, shade from the bottom right, no border at all.
  factory neumorphic() => _ToastVisual(
    plate: (theme, accent, body) => DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: BorderRadius.circular(PureRadii.md),
        boxShadow: _raised(theme),
      ),
      child: body,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    gap: 10,
    iconSize: 18,
    maxWidth: 420,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.18),
    curve: Curves.easeOutBack,
  );

  /// The wind bar: the same rule-and-border grammar as Fluent's info bar, but
  /// crisper — the fork's own small corner, a thinner rule and tighter air — so
  /// the two shadcn-lineage languages disagree about density.
  factory wind() => _ToastVisual(
    plate: (theme, accent, body) => _ruled(
      theme,
      body,
      accent,
      radius: theme.token.scale.radii.base,
      rule: 2,
      border: theme.colors.borderSecondary,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    gap: 8,
    iconSize: 15,
    maxWidth: 420,
    glyph: _sdkGlyph,
    iconTint: (theme, accent) => accent,
    content: (theme) => theme.colors.text,
    badge: false,
    beginOffset: const Offset(0, -0.2),
    curve: Curves.easeOut,
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

  /// Whether the glyph sits in the round badge Ubuntu puts in front of a
  /// notification.
  final bool badge;

  /// The offset the plate slides down from, and the curve it arrives on.
  final Offset beginOffset;
  final Curve curve;
}

/// How the plate's leading mark is drawn: nothing, a rule, or a round badge.
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

/// The plain card plate: a fill, an optional hairline, and an elevation shadow.
Widget _card(
  PureTheme theme,
  Widget body, {
  required double radius,
  required Color fill,
  required double elevation,
  Color? border,
}) => DecoratedBox(
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: border == null ? null : Border.all(color: border),
    boxShadow: _elevation(theme, elevation),
  ),
  child: body,
);

/// The surface a blurred language draws its plate on: a real backdrop filter when
/// the theme allows transparency, a plain filled panel when it does not, and a
/// hair edge in both cases. The blur sits inside the clip, so no blurred
/// rectangle bleeds past the plate's own rounded corners.
Widget _frost(
  PureTheme theme,
  Widget body, {
  required double radius,
  required Color fill,
  required double sigma,
  required Color edge,
  required double elevation,
}) {
  final rounded = BorderRadius.circular(radius > PureRadii.pill ? PureRadii.pill : radius);
  final card = DecoratedBox(
    decoration: BoxDecoration(
      color: theme.canBlur ? fill.withValues(alpha: fill.a * 0.85) : fill,
      borderRadius: rounded,
      border: Border.all(color: edge),
      boxShadow: _elevation(theme, elevation),
    ),
    child: body,
  );
  if (!theme.canBlur) {
    return card;
  }
  return ClipRRect(
    borderRadius: rounded,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: card,
    ),
  );
}

/// The elevation shadow a bordered plate floats on.
List<BoxShadow> _elevation(PureTheme theme, double blur) => [
  BoxShadow(
    color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.5 : 0.2),
    blurRadius: blur,
    offset: Offset(0, blur / 4),
  ),
];

/// The neumorphic pair: light from the top left, shade from the bottom right.
List<BoxShadow> _raised(PureTheme theme) => [
  BoxShadow(
    color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.5 : 0.18),
    blurRadius: 14,
    offset: const Offset(6, 6),
  ),
  BoxShadow(
    color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.7),
    blurRadius: 14,
    offset: const Offset(-6, -6),
  ),
];

/// The glyph set the SDK's own platforms draw these marks with; shared by every
/// language but the two Apple ones.
IconData _sdkGlyph(PureToastType type) => switch (type) {
  PureToastType.info => Icons.info_outline,
  PureToastType.success => Icons.check_circle_outline,
  PureToastType.warning => Icons.warning_amber_rounded,
  PureToastType.error => Icons.error_outline,
};

/// iOS's set.
IconData _cupertinoGlyph(PureToastType type) => switch (type) {
  PureToastType.info => CupertinoIcons.info,
  PureToastType.success => CupertinoIcons.checkmark_circle,
  PureToastType.warning => CupertinoIcons.exclamationmark_triangle,
  PureToastType.error => CupertinoIcons.exclamationmark_circle,
};

/// The macOS set: the same Cupertino library macOS draws from, with its own info
/// and error glyphs.
IconData _macosGlyph(PureToastType type) => switch (type) {
  PureToastType.info => CupertinoIcons.info_circle,
  PureToastType.success => CupertinoIcons.checkmark_circle,
  PureToastType.warning => CupertinoIcons.exclamationmark_triangle,
  PureToastType.error => CupertinoIcons.xmark_circle,
};

/// The toast plate for the active design language.
_ToastVisual _toastVisual(PureTheme theme) => switch (theme.config.language) {
  PureDesignLanguage.material => _ToastVisual.material(),
  PureDesignLanguage.cupertino => _ToastVisual.cupertino(),
  PureDesignLanguage.macos => _ToastVisual.macos(),
  PureDesignLanguage.fluent => _ToastVisual.fluent(),
  PureDesignLanguage.yaru => _ToastVisual.yaru(),
  PureDesignLanguage.forui => _ToastVisual.forui(),
  PureDesignLanguage.glass => _ToastVisual.glass(),
  PureDesignLanguage.neumorphic => _ToastVisual.neumorphic(),
  PureDesignLanguage.wind => _ToastVisual.wind(),
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
