import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/style.dart';

/// The public card: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's surface.
class LiveCard extends StatelessWidget {
  /// A card wrapping [child].
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.bordered = false,
    this.dense = false,
    this.padding,
    this.focusNode,
    this.autofocus = false,
    this.style,
    super.key,
  });

  /// The card content.
  final Widget child;

  /// The tap handler.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the card shows a selected state.
  final bool selected;

  /// Whether the card is bordered.
  final bool bordered;

  /// Whether the card uses a tighter padding.
  final bool dense;

  /// An explicit inner padding.
  final EdgeInsetsGeometry? padding;

  /// A focus node and first-focus flag.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An inline style override.
  final Style? style;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.card(
    context,
    LanguageCardSpec(
      child: child,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      bordered: bordered,
      dense: dense,
      padding: padding,
      focusNode: focusNode,
      autofocus: autofocus,
      style: style,
    ),
  );
}

/// A selectable list row: a thin dispatcher to the active language adapter.
class LiveListRow extends StatelessWidget {
  /// A list row.
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.divided = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The primary text.
  final String title;

  /// A secondary line of text.
  final String? subtitle;

  /// A leading widget (icon, avatar, thumbnail).
  final Widget? leading;

  /// A trailing widget (chevron, switch, badge).
  final Widget? trailing;

  /// The tap handler; null renders the row non-interactive.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the row shows the selected state.
  final bool selected;

  /// Whether to paint a divider under the row.
  final bool divided;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.listRow(
    context,
    LanguageListRowSpec(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      divided: divided,
      focusNode: focusNode,
      autofocus: autofocus,
    ),
  );
}
