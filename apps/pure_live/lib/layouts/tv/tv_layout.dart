import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The TV layout: the destinations across the top as focusable pills, the
/// content beneath.
///
/// Focus travel is the interaction — the pill row is the first focus stop
/// and a dpad's left and right walk it — which is why the pills are plain
/// focusable controls rather than a navigation bar.
final class TvLayout extends StatelessWidget {
  /// A TV layout over [content].
  const TvLayout({
    required this.content,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The navigation destinations, in order.
  final List<NavigationItem> items;

  /// The selected destination's index.
  final int selectedIndex;

  /// Fired when the viewer presses a pill.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                for (final (index, item) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TvPill(
                      label: item.label(context.t),
                      icon: item.icon,
                      selected: index == selectedIndex,
                      autofocus: index == 0,
                      onSelected: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

final class _TvPill extends StatelessWidget {
  const _TvPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.autofocus = false,
  });

  final String label;
  final DsIconData icon;
  final bool selected;
  final VoidCallback onSelected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: onSelected,
      autofocus: autofocus,
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.surface,
            border: Border.all(color: focused ? colors.text : colors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 14, color: selected ? colors.onAccent : colors.textMuted),
              const SizedBox(width: 8),
              Text(label, style: DsTheme.of(context).typography.label),
            ],
          ),
        );
      },
    );
  }
}
