import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The card surface every page uses.
///
/// A card is the container for a room tile, a settings group, a channel row
/// — the language decides its fill, radius and elevation, and whether tap
/// and focus make it interactive at all.
class LiveCard extends StatelessWidget {
  /// A card.
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.dense = false,
    this.selected = false,
    this.padding,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The card's content.
  final Widget child;

  /// The tap callback; null makes the card non-interactive.
  final VoidCallback? onTap;

  /// The long-press callback, for context menus.
  final VoidCallback? onLongPress;

  /// Whether the card packs its content tighter.
  final bool dense;

  /// Whether the card renders as selected.
  final bool selected;

  /// Overrides the token padding when the content manages its own insets.
  final EdgeInsetsGeometry? padding;

  /// The focus node, for lists that manage focus themselves.
  final FocusNode? focusNode;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.card(
    context,
    LiveCardSpec(
      child: child,
      onTap: onTap,
      onLongPress: onLongPress,
      dense: dense,
      selected: selected,
      padding: padding,
      focusNode: focusNode,
      autofocus: autofocus,
    ),
  );
}
