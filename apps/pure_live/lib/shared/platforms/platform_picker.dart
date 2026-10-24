import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// The special scope meaning "every platform" — the platform tabs' first
/// entry on the pages that offer one (follows, search).
const String kAllPlatforms = 'all';

/// The platform tabs row under a page's title: one tab per platform, the
/// row scrolling when the names overflow, and a dropdown chevron at its
/// end opening every platform in a menu (the reference's
/// ScrollableTabBar + ⌄ picker).
///
/// The current platform follows the theme's selection; choosing from the
/// menu behaves exactly like tapping its tab.
final class PlatformTabRow extends StatelessWidget {
  /// Tabs over [platforms], [current] selected.
  const PlatformTabRow({
    required this.platforms,
    required this.current,
    required this.onChanged,
    required this.nameOf,
    this.semanticLabel,
    super.key,
  });

  /// The platform ids shown, in tab order. [kAllPlatforms] may lead.
  final List<String> platforms;

  /// The selected platform id.
  final String current;

  /// Fired with the id of the platform picked, from a tab or the menu.
  final ValueChanged<String> onChanged;

  /// A platform id's display name ('all' names itself).
  final String Function(String id) nameOf;

  /// Names the row for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final children = <Widget>[
      Expanded(
        child: DsTopNav<String>(
          semanticLabel: semanticLabel,
          value: current,
          onChanged: onChanged,
          items: [
            for (final id in platforms) DsTopNavItem(value: id, label: Text(nameOf(id))),
          ],
        ),
      ),
      const SizedBox(width: DsSpace.s8),
      // The dropdown: every platform in one menu, the current one checked.
      DsMenuAnchor(
        items: [
          for (final id in platforms)
            DsMenuItem(
              label: Text(nameOf(id)),
              trailing: id == current ? const DsIcon(DsIcons.check, size: 16) : null,
              onPressed: () => onChanged(id),
            ),
        ],
        builder: (context, controller, _) => DsPressable(
          semanticLabel: context.t.common.switchModule,
          onPressed: controller.toggle,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            return Container(
              width: 30,
              height: 30,
              decoration: DsBoxDecoration(
                color: controller.isOpen || hovered ? colors.hover : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: DsIcon(DsIcons.chevronDown, size: 16, color: colors.textMuted),
              ),
            );
          },
        ),
      ),
    ];
    return SizedBox(height: 36, child: Row(children: children));
  }
}
