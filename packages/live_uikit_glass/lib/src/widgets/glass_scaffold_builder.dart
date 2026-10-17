import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted page frame from a [LanguageScaffoldSpec] (§9 Scaffold).
///
/// Composed, not mapped: `glass_morphism_plus` has no frame — `GlassAppBar` is
/// its only structural widget and it is a Material bar — so the page is one
/// full-bleed [glass.GlassContainer] sheet, the library's own surface, with the
/// dispatched bar above the content, the bottom strip under it and the floating
/// action held at the trailing corner. The sheet blurs what the app paints behind
/// it, which is the whole point of the language: a glass page is a lit panel over
/// a background, not a colour.
///
/// This frame paints no `Material` of its own: the library wraps an ink host
/// inside any surface that takes a tap, and the page sheet takes none, so a frame
/// that supplies no ink host of its own is not a frame that crashes (§15).
///
/// [LanguageScaffoldSpec.background] tints that sheet instead of replacing it — a
/// glass frame has no opaque side to swap — and keeps the theme's tint when the
/// caller names none. [LanguageScaffoldSpec.avoidKeyboard] is answered with the
/// view insets, since this frame is not a Material scaffold with a resize policy
/// of its own, and [LanguageScaffoldSpec.extendBodyBehindAppBar] lays the bar over
/// the content in a stack, which is the reading this contract gives it.
abstract final class GlassScaffoldBuilder {
  /// Builds the frame for [spec].
  static Widget build(BuildContext context, LanguageScaffoldSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = spec.avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = spec.appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: bar == null && !spec.extendBodyBehindAppBar,
        bottom: spec.bottomBar == null,
        child: spec.body,
      ),
    );

    final Widget body;
    if (bar == null) {
      body = content;
    } else if (spec.extendBodyBehindAppBar) {
      body = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ],
      );
    } else {
      body = Column(
        children: [
          bar,
          Expanded(child: content),
        ],
      );
    }

    final bottom = spec.bottomBar;
    final frame = bottom == null
        ? body
        : Column(
            children: [
              Expanded(child: body),
              bottom,
            ],
          );

    final sheet = glass.GlassContainer(color: spec.background ?? glassTheme.color, child: frame);

    final action = spec.floatingActionButton;
    if (action == null) {
      return SizedBox.expand(child: sheet);
    }
    return Stack(
      children: [
        Positioned.fill(child: sheet),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }
}
