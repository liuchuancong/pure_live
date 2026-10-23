import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/i18n/translations.g.dart';
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The mobile layout: the content above a bottom navigation bar.
///
/// The bar the thumb reaches — icons plus labels — not a folded desktop
/// rail.
final class MobileLayout extends StatelessWidget {
  /// A mobile layout over [content].
  const MobileLayout({
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

  /// Fired when the viewer picks a destination.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      children: [
        Expanded(child: content),
        DsBottomNav(
          value: selectedIndex,
          onChanged: onSelected,
          items: [
            for (final (index, item) in items.indexed)
              DsBottomNavItem(value: index, icon: DsIcon(item.icon), label: Text(item.label(t))),
          ],
        ),
      ],
    );
  }
}
