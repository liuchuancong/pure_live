import 'dart:async';

import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;

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
/// what the active design language decides is the pill itself: the surface
/// builder switches on `UiConfig.language` and constructs the language's own
/// component — Fluent's `FluentToast`, a macOS `MacosSheet` HUD, a Cupertino
/// `CupertinoPopupSurface` panel, a Material card dressed from the library's
/// own `SnackBarThemeData`, ForUI's `FToast`, and for the surface libraries
/// that ship no message widget (glass, neumorphic, wind) a hand-rolled pill in
/// that language's own idiom — so what the user sees is exactly what that
/// library's own documentation shows. Switching `UiConfig.language` re-skins
/// every toast. Nothing here needs a
/// `Scaffold`: the message goes to the root [Overlay], so a toast fired from a
/// route, a dialog or a second desktop window still finds its way to the top
/// of the screen.
abstract final class PureToast {
  /// Shows [message] for [duration], then removes it.
  ///
  /// A context with no [Overlay] above it (a bare test harness, a window still
  /// building) is not an error worth crashing over: the call is dropped, since
  /// the message had nowhere to be drawn anyway.
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

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        theme: theme,
        lifetime: duration,
        onFinished: () => entry.remove(),
        // Resolved inside the overlay's own context, so an inherited theme
        // change during the message's life does not leave it on the old skin.
        child: Builder(builder: (inner) => _toastSurface(inner, theme, spec)),
      ),
    );
    overlay.insert(entry);
  }

  /// The toast surface for the active design language: the language's own
  /// toast widget, or — for the surface libraries that ship no toast — the
  /// language's own panel composed into one.
  static Widget _toastSurface(BuildContext context, PureTheme theme, _ToastSpec spec) {
    return switch (theme.config.language) {
      // Yaru draws toasts with the Material card — that is what Yaru itself is;
      // its character comes from the host theme.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialToast(context, theme, spec),
      PureDesignLanguage.cupertino => _cupertinoToast(context, theme, spec),
      PureDesignLanguage.macos => _macosToast(context, theme, spec),
      PureDesignLanguage.fluent => _fluentToast(context, spec),
      PureDesignLanguage.forui => _foruiToast(theme, spec),
      PureDesignLanguage.glass => _glassToast(context, theme, spec),
      PureDesignLanguage.neumorphic => _neumorphicToast(context, theme, spec),
      PureDesignLanguage.wind => _windToast(theme, spec),
    };
  }

  /// The status colour a kind maps to, unless the caller overrode it.
  static Color _accent(PureTheme theme, _ToastSpec spec) => switch (spec.type) {
    PureToastType.info => theme.colors.info,
    PureToastType.success => theme.colors.success,
    PureToastType.warning => theme.colors.warning,
    PureToastType.error => theme.colors.error,
  };

  /// The Material surface: a `Material` card dressed from the library's own
  /// `SnackBarThemeData`, not a `SnackBar` — the library's bar reads
  /// `widget.animation!` in `initState` and is only ever built by a
  /// `ScaffoldMessenger` that owns that animation, so a `SnackBar` handed to a
  /// caller-owned overlay throws. The colour, elevation, shape and text role
  /// still come from `SnackBarThemeData`, which is where Material keeps those
  /// decisions, so the surface is still the library's.
  static Widget _materialToast(BuildContext context, PureTheme theme, _ToastSpec spec) {
    final bar = Theme.of(context).snackBarTheme;
    final accent = spec.accent ?? _accent(theme, spec);
    final body = theme.text.body.merge(bar.contentTextStyle).copyWith(color: theme.colors.text);

    return Material(
      type: MaterialType.card,
      color: bar.backgroundColor ?? theme.colors.bgElevated,
      elevation: bar.elevation ?? 6,
      shape: bar.shape,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon ?? _glyph(spec.type), color: accent, size: body.fontSize),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  /// The Cupertino surface: the library ships no toast and iOS itself has no
  /// transient message bar — what it has is the HUD, a blurred rounded panel,
  /// which is [cupertino.CupertinoPopupSurface].
  static Widget _cupertinoToast(BuildContext context, PureTheme theme, _ToastSpec spec) {
    final accent = spec.accent ?? _accent(theme, spec);
    final body = theme.text.body.copyWith(color: theme.colors.text);

    return cupertino.CupertinoPopupSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon ?? _cupertinoGlyph(spec.type), color: accent, size: body.fontSize),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  /// The macOS surface: the library has no transient message widget, so it is
  /// composed from the library's own floating panel, `MacosSheet` — what a
  /// macOS HUD is drawn from. `insetPadding` is zeroed because the core's
  /// `Align(topCenter)` does the placing and this is only the surface.
  static Widget _macosToast(BuildContext context, PureTheme theme, _ToastSpec spec) {
    final accent = spec.accent ?? _accent(theme, spec);
    final body = theme.text.body.copyWith(color: theme.colors.text);

    return macos.MacosSheet(
      insetPadding: EdgeInsets.zero,
      backgroundColor: theme.colors.bgElevated,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            macos.MacosIcon(spec.icon ?? _macosGlyph(spec.type), color: accent),
            SizedBox(width: theme.token.scale.sizes.sm),
            Flexible(child: Text(spec.message, style: body)),
          ],
        ),
      ),
    );
  }

  /// The Fluent surface: the library's own `FluentToast`, whose intent decides
  /// the glyph — so [_ToastSpec.icon] and [_ToastSpec.accent]
  /// are unmapped here, because forcing an override glyph or colour onto it
  /// would give a Fluent screen a toast Fluent does not recognise.
  static Widget _fluentToast(BuildContext context, _ToastSpec spec) {
    return f2.FluentToast(
      title: Text(spec.message),
      intent: switch (spec.type) {
        PureToastType.info => f2.FluentToastIntent.info,
        PureToastType.success => f2.FluentToastIntent.success,
        PureToastType.warning => f2.FluentToastIntent.warning,
        PureToastType.error => f2.FluentToastIntent.error,
      },
    );
  }

  static IconData _glyph(PureToastType type) => switch (type) {
    PureToastType.info => Icons.info_outline,
    PureToastType.success => Icons.check_circle_outline,
    PureToastType.warning => Icons.warning_amber_rounded,
    PureToastType.error => Icons.error_outline,
  };

  /// The ForUI surface: the library's own `FToast` message body — a plain
  /// widget that asks nothing of an ancestor, so only the toaster around it
  /// (`FToaster`, `showFToast`) stays the core's. Severity maps to the
  /// library's own two variants while the glyph keeps the token's status
  /// colour, written through the style delta on the icon style rather than
  /// hand-tinting a row the library already themes.
  static Widget _foruiToast(PureTheme theme, _ToastSpec spec) {
    final accent = spec.accent ?? _accent(theme, spec);
    return forui.FToast(
      variant: switch (spec.type) {
        PureToastType.warning || PureToastType.error => forui.FToastVariant.destructive,
        PureToastType.info || PureToastType.success => forui.FToastVariant.primary,
      },
      icon: Icon(spec.icon ?? _glyph(spec.type)),
      title: Text(spec.message),
      style: forui.FToastStyleDelta.delta(iconStyle: forui.IconThemeDataDelta.delta(color: accent)),
    );
  }

  // Hand-rolled because the library ships no message widget: a frosted
  // `GlassContainer` pill — its blur, tint, corner radius and stroke all the
  // values `GlassTheme` publishes. Glass marks severity on the glyph rather
  // than a solid fill, which a translucent surface could not hold.
  static Widget _glassToast(BuildContext context, PureTheme theme, _ToastSpec spec) {
    final glassTheme = glass.GlassTheme.of(context);
    final accent = spec.accent ?? _accent(theme, spec);
    final sizes = theme.token.scale.sizes;

    return glass.GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: sizes.md, vertical: sizes.sm),
      elevation: 6,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon ?? _glyph(spec.type), color: accent, size: theme.text.body.fontSize),
          SizedBox(width: sizes.sm),
          Flexible(child: Text(spec.message, style: theme.text.body.copyWith(color: theme.colors.text))),
        ],
      ),
    );
  }

  // Hand-rolled because the library ships no transient message: the pill is a
  // `NeuContainer` plane at the theme's own depth, radius and base colour.
  static Widget _neumorphicToast(BuildContext context, PureTheme theme, _ToastSpec spec) {
    final surface = neu.NeuTheme.of(context);
    final accent = spec.accent ?? _accent(theme, spec);
    final sizes = theme.token.scale.sizes;

    return neu.NeuContainer(
      baseColor: surface.baseColor,
      borderRadius: surface.borderRadius,
      depth: surface.depth,
      distance: surface.distance,
      padding: EdgeInsets.symmetric(horizontal: sizes.md, vertical: sizes.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon ?? _glyph(spec.type), color: accent, size: theme.text.body.fontSize),
          SizedBox(width: sizes.sm),
          Flexible(child: Text(spec.message, style: theme.text.body.copyWith(color: theme.colors.text))),
        ],
      ),
    );
  }

  // Hand-rolled because the fork has no transient message widget at all: the
  // pill is the library's own floating panel, `WCard` — `rounded-2xl
  // shadow-lg border` over its elevated background pair, the message at the
  // library's `text-sm` step — with the status colour arriving through the
  // fork's documented runtime-colour channel (`WIcon.foregroundColor`).
  static Widget _windToast(PureTheme theme, _ToastSpec spec) {
    final accent = spec.accent ?? _accent(theme, spec);
    return wind.WCard(
      className:
          'rounded-2xl shadow-lg border bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700'
          ' text-gray-900 dark:text-gray-100',
      child: wind.WDiv(
        className: 'flex flex-row items-center gap-2 px-4 py-2',
        children: [
          wind.WIcon(spec.icon ?? _glyph(spec.type), className: 'text-sm', foregroundColor: accent),
          wind.WText(spec.message, className: 'text-sm shrink'),
        ],
      ),
    );
  }

  /// The glyphs the Cupertino set draws.
  static IconData _cupertinoGlyph(PureToastType type) => switch (type) {
    PureToastType.info => cupertino.CupertinoIcons.info,
    PureToastType.success => cupertino.CupertinoIcons.checkmark_circle,
    PureToastType.warning => cupertino.CupertinoIcons.exclamationmark_triangle,
    PureToastType.error => cupertino.CupertinoIcons.exclamationmark_circle,
  };

  /// The macOS set: the same Cupertino library macOS draws from (which
  /// `macos_ui` uses internally but does not re-export, so it is taken from
  /// the SDK), with its own info and error glyphs.
  static IconData _macosGlyph(PureToastType type) => switch (type) {
    PureToastType.info => cupertino.CupertinoIcons.info_circle,
    PureToastType.success => cupertino.CupertinoIcons.checkmark_circle,
    PureToastType.warning => cupertino.CupertinoIcons.exclamationmark_triangle,
    PureToastType.error => cupertino.CupertinoIcons.xmark_circle,
  };
}

class _ToastOverlay extends StatefulWidget {
  const new({required this.theme, required this.lifetime, required this.onFinished, required this.child});

  final PureTheme theme;
  final Duration lifetime;
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.theme.duration);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.lifetime, _dismiss);
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.lg),
            child: FadeTransition(
              opacity: _controller,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(_controller),
                child: widget.child,
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
