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

/// A hover/focus tooltip — Ant's `Tooltip`.
///
/// Under each language the bubble is that language's own tooltip, constructed
/// directly: the SDK `Tooltip` under material (which takes [waitDuration]
/// natively; yaru rides it), `MacosTooltip` under macOS, `FluentTooltip` under
/// fluent, `FTooltip` under forui — so what the user sees is exactly what that
/// library's own documentation shows. Switching `UiConfig.language` re-skins
/// every tooltip. [waitDuration] is a Material statement: macOS, Fluent and
/// ForUI fix their own dwell in their libraries, so they do not take the knob,
/// the same way a knob is unmapped where the library has no slot for it.
///
/// Cupertino ships no tooltip, and neither do glass, neumorphic or wind; those
/// bubbles are hand-rolled into the shared hover/focus overlay below — an iOS
/// slab of dynamic-coloured system grey from the cupertino primitives, and
/// that surface library's own floating panel for the other three.
class PureTooltip extends StatefulWidget {
  /// A tooltip around [child].
  const new({
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
    super.key,
  });

  /// The text to reveal.
  final String message;

  /// The hovered widget.
  final Widget child;

  /// How long the pointer must rest before the bubble appears.
  final Duration waitDuration;

  @override
  State<PureTooltip> createState() => _PureTooltipState();
}

class _PureTooltipState extends State<PureTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;

  /// The bubble the shared overlay opens, for the languages whose libraries
  /// ship no tooltip widget ([_anchored] stores it, [_show] reads it).
  Widget Function(BuildContext context, PureTheme theme, String message)? _bubbleBuilder;

  void _show() {
    if (_entry != null || _bubbleBuilder == null) {
      return;
    }
    final theme = PureTheme.of(context);
    final surface = _bubbleBuilder!;
    _entry = OverlayEntry(
      builder: (_) => _Bubble(link: _link, theme: theme, message: widget.message, surface: surface),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  void _scheduleShow() {
    _timer?.cancel();
    _timer = Timer(widget.waitDuration, _show);
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (PureTheme.of(context).config.language) {
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru => Tooltip(message: widget.message, waitDuration: widget.waitDuration, child: widget.child),
      PureDesignLanguage.cupertino => _anchored(_cupertinoBubble),
      PureDesignLanguage.macos => macos.MacosTooltip(message: widget.message, child: widget.child),
      PureDesignLanguage.fluent => f2.FluentTooltip(content: Text(widget.message), child: widget.child),
      PureDesignLanguage.forui => forui.FTooltip(
        tipBuilder: (context, controller) => Text(widget.message),
        child: widget.child,
      ),
      PureDesignLanguage.glass => _anchored(_glassBubble),
      PureDesignLanguage.neumorphic => _anchored(_neumorphicBubble),
      PureDesignLanguage.wind => _anchored(_windBubble),
    };
  }

  /// The hover/focus trigger for the languages whose bubble is hand-rolled
  /// into the shared overlay: it records which bubble to open, then targets
  /// the follower.
  Widget _anchored(Widget Function(BuildContext context, PureTheme theme, String message) bubble) {
    _bubbleBuilder = bubble;
    return MouseRegion(
      onEnter: (_) => _scheduleShow(),
      onExit: (_) => _hide(),
      child: Focus(
        onFocusChange: (focused) => focused ? _show() : _hide(),
        child: CompositedTransformTarget(link: _link, child: widget.child),
      ),
    );
  }

  // Hand-rolled because Cupertino ships no tooltip widget: an iOS bubble is a
  // small rounded slab of the system grey, its colours Cupertino dynamic
  // colours resolved against the ambient brightness.
  static Widget _cupertinoBubble(BuildContext context, PureTheme theme, String message) {
    const fill = cupertino.CupertinoDynamicColor.withBrightness(color: Color(0xE628282A), darkColor: Color(0xEBF2F2F7));
    const ink = cupertino.CupertinoDynamicColor.withBrightness(color: Color(0xFFFFFFFF), darkColor: Color(0xFF000000));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
      decoration: BoxDecoration(
        color: cupertino.CupertinoDynamicColor.resolve(fill, context),
        borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
        boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Text(
        message,
        style: theme.text.bodySmall.copyWith(color: cupertino.CupertinoDynamicColor.resolve(ink, context)),
      ),
    );
  }

  // Hand-rolled because the library ships no tooltip widget: the label rides a
  // frosted `GlassContainer` sheet read from the library's own `GlassTheme`.
  static Widget _glassBubble(BuildContext context, PureTheme theme, String message) {
    final glassTheme = glass.GlassTheme.of(context);
    return glass.GlassContainer(
      blur: glassTheme.blur,
      opacity: glassTheme.opacity,
      borderRadius: glassTheme.borderRadius,
      color: theme.colors.bgSpotlight,
      elevation: glassTheme.elevation ?? 4,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
      child: Text(message, style: theme.text.bodySmall.copyWith(color: theme.colors.textLightSolid)),
    );
  }

  // Hand-rolled because the library ships no tooltip widget: the label rides a
  // `NeuContainer` domed ([neu.NeuShape.convex]) off the page at the theme's
  // own depth.
  static Widget _neumorphicBubble(BuildContext context, PureTheme theme, String message) {
    final surface = neu.NeuTheme.of(context);
    return neu.NeuContainer(
      shape: neu.NeuShape.convex,
      baseColor: surface.baseColor,
      depth: surface.depth,
      distance: surface.distance,
      borderRadius: surface.borderRadius,
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
      child: Text(message, style: theme.text.bodySmall.copyWith(color: theme.colors.text)),
    );
  }

  // Hand-rolled because the fork ships no tooltip widget: the label rides the
  // library's own floating panel, `WCard` — `rounded-lg shadow-lg border` over
  // its elevated background pair, the message at its `text-sm` step.
  static Widget _windBubble(BuildContext context, PureTheme theme, String message) {
    return wind.WCard(
      className:
          'rounded-lg shadow-lg border bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700'
          ' text-gray-900 dark:text-gray-100',
      child: wind.WDiv(
        className: 'px-2 py-1',
        children: [wind.WText(message, className: 'text-sm')],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.link, required this.theme, required this.message, required this.surface});

  final LayerLink link;
  final PureTheme theme;
  final String message;
  final Widget Function(BuildContext context, PureTheme theme, String message) surface;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      offset: Offset(0, -theme.token.scale.sizes.sm),
      child: IgnorePointer(child: surface(context, theme, message)),
    );
  }
}
