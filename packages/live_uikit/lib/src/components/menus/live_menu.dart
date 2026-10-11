import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The menu every page uses: an anchor widget and the entries to pop up
/// beside it.
///
/// The anchor is a normal widget (usually a `LiveIconButton` or a
/// `LiveButton`) so a menu looks like whatever the page needs, while the
/// entries, their enabled and danger states and the selection callback stay
/// one contract for all six languages.
class LiveMenuButton extends StatelessWidget {
  /// A menu anchored at [child].
  const new({
    required this.child,
    required this.entries,
    required this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.focusNode,
    super.key,
  });

  /// The anchor the menu opens from.
  final Widget child;

  /// The entries, in display order.
  final List<LiveMenuEntry> entries;

  /// Called with the chosen entry's id.
  final ValueChanged<String> onSelected;

  /// Whether the anchor opens the menu.
  final bool enabled;

  /// An optional tooltip for the anchor.
  final String? tooltip;

  /// The anchor's focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.menu(
    context,
    LiveMenuSpec(
      child: child,
      entries: entries,
      onSelected: onSelected,
      enabled: enabled,
      tooltip: tooltip,
      focusNode: focusNode,
    ),
  );
}
