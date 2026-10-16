import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_environment.dart';

/// The token-driven page frame: a background surface, the bars stacked around
/// the content, and a floating action held at the trailing bottom corner.
///
/// It deliberately does not use Material's frame. A `Scaffold` brings its own
/// elevation shadows, its resize-on-keyboard policy and a floating-action
/// placement rule of its own, and those read as Material in every language —
/// which is precisely how a design-language switch ends up changing nothing.
class TokenScaffold extends StatelessWidget {
  /// A token frame built from [spec].
  const new({required this.spec, super.key});

  /// The frame configuration.
  final LanguageScaffoldSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = spec.avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final surfaceColor = spec.background ?? theme.colors.bgLayout;
    final bar = spec.appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      // The top inset belongs to the bar when the content runs under it; the
      // bottom one belongs to the frame unless a bottom bar already sits there.
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

    final action = spec.floatingActionButton;
    // `MaterialType.canvas` rather than a `ColoredBox`: the frame is what gives
    // every descendant its Material ancestor — an `InkWell` in a card, text
    // selection, a tooltip, the ink of a menu item. Material's own frame did
    // this on the side effect; a token frame that only paints a box would make
    // the page crash on the first control that asks for it.
    final surface = Material(color: surfaceColor, child: frame);
    if (action == null) {
      return surface;
    }
    return Stack(
      children: [
        Positioned.fill(child: surface),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }
}

/// The public page frame: a thin dispatcher to the active language adapter.
class LiveScaffold extends StatelessWidget {
  /// A page frame around [body].
  const new({
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.background,
    this.extendBodyBehindAppBar = false,
    this.avoidKeyboard = true,
    super.key,
  });

  /// The page content.
  final Widget body;

  /// The top bar — pass a `LiveAppBar` so the bar itself dispatches too.
  final Widget? appBar;

  /// A bottom bar: the shell's navigation, a tab strip, an action row.
  final Widget? bottomBar;

  /// A floating action, held at the trailing bottom corner.
  final Widget? floatingActionButton;

  /// A background override; null keeps the theme's layout surface.
  final Color? background;

  /// Whether [body] starts under [appBar] instead of below it.
  final bool extendBodyBehindAppBar;

  /// Whether the content keeps clear of an open on-screen keyboard.
  final bool avoidKeyboard;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.scaffold(
    context,
    LanguageScaffoldSpec(
      body: body,
      appBar: appBar,
      bottomBar: bottomBar,
      floatingActionButton: floatingActionButton,
      background: background,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      avoidKeyboard: avoidKeyboard,
    ),
  );
}
