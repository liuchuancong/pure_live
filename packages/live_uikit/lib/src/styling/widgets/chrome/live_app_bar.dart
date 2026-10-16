import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_environment.dart';

/// The token-driven top bar: a fixed-height title row over an optional strip,
/// on the theme's header surface, closed by a hairline.
///
/// The height comes from the layout environment rather than a literal, so a TV
/// build gets a bar a remote can read across a room from the same code a phone
/// build does.
class TokenAppBar extends StatelessWidget {
  /// A token bar built from [spec].
  const new({required this.spec, super.key});

  /// The bar configuration.
  final LanguageAppBarSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = spec.height ?? geometry?.appBarHeight ?? 56;
    final padding = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final gap = theme.token.scale.sizes.sm;
    // The token base left-aligns because that is what the desktop libraries do;
    // a caller who wants a centred title asks for it explicitly.
    final center = spec.centerTitle ?? false;

    return ColoredBox(
      color: spec.background ?? theme.colors.bgElevated,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  if (spec.leading case final lead?) ...[lead, SizedBox(width: gap)],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        spec.title,
                        textAlign: center ? TextAlign.center : TextAlign.start,
                        style: theme.text.title.copyWith(color: theme.colors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (spec.actions.isNotEmpty) ...[
                    SizedBox(width: gap),
                    for (final action in spec.actions) ...[action, SizedBox(width: gap)],
                  ],
                ],
              ),
            ),
          ),
          ?spec.bottom,
          Container(height: theme.token.motion.lineWidth, color: theme.colors.border),
        ],
      ),
    );
  }
}

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
