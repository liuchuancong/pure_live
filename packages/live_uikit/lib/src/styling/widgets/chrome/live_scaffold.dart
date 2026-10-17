import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

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
