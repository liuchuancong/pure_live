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
      // The dropdown: every platform in a panel — a side sheet on a wide
      // window, a half-height (pullable to full) sheet on a narrow one;
      // the current one checked.
      DsButton(
        variant: DsButtonVariant.secondary,
        onPressed: () => showDsPanel<void>(
          context: context,
          // auto (the default) is exactly the rule: side on a wide window,
          // bottom on a narrow one.
          detents: const [0.5, 1],
          builder: (context) => DsPanel(
            title: Text(context.t.popular.allPlatforms),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final id in platforms)
                  DsListRow(
                    title: Text(nameOf(id)),
                    trailing: id == current ? const DsIcon(DsIcons.check, size: 16) : null,
                    onPressed: () {
                      onChanged(id);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
        child: const DsIcon(DsIcons.chevronDown, size: 16),
      ),
    ];
    return SizedBox(height: 36, child: Row(children: children));
  }
}
