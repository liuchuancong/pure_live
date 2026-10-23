import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/shell/navigation/navigation_item.dart' show NavigationItem;
import 'package:pure_live/i18n/translations.g.dart';

/// One focusable destination in the TV shell's top row.
final class TvNavigationPill extends StatelessWidget {
  /// A pill for [item].
  const new({required this.item, required this.selected, required this.onSelected, this.autofocus = false, super.key});

  /// The branch this pill opens.
  final NavigationItem item;

  /// Whether the shell is showing this pill's branch.
  final bool selected;

  /// Fired when the viewer presses the pill.
  final VoidCallback onSelected;

  /// Whether the pill takes the remote's focus first.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: DsPressable(
        semanticLabel: item.label(t),
        onPressed: onSelected,
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
                DsIcon(item.icon, size: 14, color: selected ? colors.onAccent : colors.textMuted),
                const SizedBox(width: 8),
                Text(item.label(t), style: DsTheme.of(context).typography.label),
              ],
            ),
          );
        },
      ),
    );
  }
}
