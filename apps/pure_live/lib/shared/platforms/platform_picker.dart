import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/layout_toggle.dart' show LayoutToggle;
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon;

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
final class PlatformTabRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    // A platform's own icon rides its tab and its picker row; the "all"
    // sentinel has none.
    Widget? iconOf(String id) => id == kAllPlatforms ? null : localizedSiteIcon(sites.getById(id));
    final children = <Widget>[
      Expanded(
        child: DsTopNav<String>(
          semanticLabel: semanticLabel,
          value: current,
          onChanged: onChanged,
          items: [for (final id in platforms) DsTopNavItem(value: id, label: Text(nameOf(id)), icon: iconOf(id))],
        ),
      ),
      const SizedBox(width: DsSpace.s8),
      // The dropdown: every platform in a panel — a side sheet on a wide
      // window, a half-height (pullable to full) sheet on a narrow one.
      // The platforms sit as a grid of choice cards, so a long catalogue
      // stays two rows shorter than a list would need.
      DsButton(
        variant: DsButtonVariant.secondary,
        onPressed: () => showDsPanel<void>(
          context: context,
          // auto (the default) is exactly the rule: side on a wide window,
          // bottom on a narrow one.
          detents: const [0.5, 1],
          builder: (context) => DsPanel(
            title: Text(context.t.popular.allPlatforms),
            // The grid scrolls itself; the panel hands it the room it has.
            scrollable: false,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisExtent: 56,
                mainAxisSpacing: DsSpace.s8,
                crossAxisSpacing: DsSpace.s8,
              ),
              itemCount: platforms.length,
              itemBuilder: (context, index) {
                final id = platforms[index];
                final name = nameOf(id);
                return DsCard(
                  // A remote opens the panel with no pointer: the shown
                  // platform is the first stop.
                  autofocus: id == current,
                  semanticLabel: name,
                  onPressed: () {
                    onChanged(id);
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      ?iconOf(id),
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (id == current) const DsIcon(DsIcons.check, size: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        child: const DsIcon(DsIcons.chevronDown, size: 16),
      ),
      const SizedBox(width: DsSpace.s8),
      const LayoutToggle(),
    ];
    return SizedBox(height: 44, child: Row(children: children));
  }
}
