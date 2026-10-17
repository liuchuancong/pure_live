import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The public top bar: a thin dispatcher to the active language adapter.
class LiveAppBar extends StatelessWidget {
  /// A bar titled [title].
  const new({
    required this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.bottom,
    this.background,
    this.centerTitle,
    this.height,
    super.key,
  });

  /// The page title.
  final String title;

  /// A widget before the title — a back affordance or a drawer button.
  final Widget? leading;

  /// Actions after the title, in order. Give them the `Live*` forms so they
  /// follow the language too.
  final List<Widget> actions;

  /// A strip under the title row, typically a tab strip.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface.
  final Color? background;

  /// Whether the title sits in the middle; null defers to the language.
  final bool? centerTitle;

  /// The title-row height; null takes the environment's bar height.
  final double? height;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.appBar(
    context,
    LanguageAppBarSpec(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      background: background,
      centerTitle: centerTitle,
      height: height,
    ),
  );
}
