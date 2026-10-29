import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart' show CardLayout;
import 'package:pure_live/shared/grids/layout_toggle.dart' show LayoutToggle;
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon;

/// The special scope meaning "every platform" — the platform tabs' first
/// entry on the pages that offer one (follows, search).
const String kAllPlatforms = 'all';

/// The chevron that opens the platform wall, so a page whose tabs are its own
/// (the follows page's underline tabs) offers the same catalogue as one that
/// uses [PlatformTabRow].
final class PlatformWallButton extends StatelessWidget {
  /// The button; [iconOf] is asked at the wall's tile size.
  const PlatformWallButton({
    required this.platforms,
    required this.current,
    required this.nameOf,
    required this.iconOf,
    required this.onChanged,
    this.onManagePlatforms,
    this.countOf,
    super.key,
  });

  /// The platform ids the wall lists, in order.
  final List<String> platforms;

  /// The selected platform id.
  final String current;

  /// A platform id's display name.
  final String Function(String id) nameOf;

  /// A platform id's tile icon.
  final Widget? Function(String id) iconOf;

  /// Fired with the id of the platform picked.
  final ValueChanged<String> onChanged;

  /// Opens the platform-display setting from the wall's header.
  final VoidCallback? onManagePlatforms;

  /// A platform's own count, shown under its name.
  final int? Function(String id)? countOf;

  @override
  Widget build(BuildContext context) {
    return DsButton(
      variant: DsButtonVariant.secondary,
      onPressed: () => unawaited(
        showPlatformPickerPanel(
          context,
          platforms: platforms,
          current: current,
          nameOf: nameOf,
          iconOf: iconOf,
          onChanged: onChanged,
          onManagePlatforms: onManagePlatforms,
          countOf: countOf,
        ),
      ),
      child: const DsIcon(DsIcons.chevronDown, size: 16),
    );
  }
}

/// The platform tabs row under a page's title
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
    this.onManagePlatforms,
    this.countOf,
    this.showLayoutToggle = true,
    this.showPlatformWall = true,
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

  /// Opens the platform-display setting, offered in the panel's header where
  /// the viewer is looking at the catalogue and may want a platform hidden
  /// or reordered. Null leaves the header with just its title.
  final VoidCallback? onManagePlatforms;

  /// A platform's own count, shown after its name on the tab and under it in
  /// the panel — what the follows page lists there. Null leaves both plain.
  final int? Function(String id)? countOf;

  /// Whether the row ends with the card/list layout switch. A page whose
  /// own grid has a different pair of shapes (the areas page's tiles and
  /// rows) passes false and draws its own switch instead of two.
  final bool showLayoutToggle;

  /// Whether the row ends with the chevron opening the platform wall. A
  /// narrow toolbar that keeps only the tabs passes false and offers the
  /// wall from its own menu.
  final bool showPlatformWall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    // A platform's own icon rides its tab and its picker tile; the "all"
    // sentinel has none.
    Widget? iconOf(String id, {double size = 16}) =>
        id == kAllPlatforms ? null : localizedSiteIcon(sites.getById(id), size: size);
    final children = <Widget>[
      Expanded(
        child: DsTopNav<String>(
          semanticLabel: semanticLabel,
          value: current,
          onChanged: onChanged,
          items: [
            for (final id in platforms)
              DsTopNavItem(
                value: id,
                label: _TabLabel(name: nameOf(id), count: countOf?.call(id)),
                icon: iconOf(id),
              ),
          ],
        ),
      ),
      if (showPlatformWall) ...[
        const SizedBox(width: DsSpace.s8),
        // The dropdown: every platform in the wall.
        PlatformWallButton(
          platforms: platforms,
          current: current,
          nameOf: nameOf,
          iconOf: (id) => iconOf(id, size: 32),
          onChanged: onChanged,
          onManagePlatforms: onManagePlatforms,
          countOf: countOf,
        ),
      ],
      if (showLayoutToggle) ...[const SizedBox(width: DsSpace.s8), const LayoutToggle()],
    ];
    return SizedBox(height: 44, child: Row(children: children));
  }
}

/// The one control a narrow toolbar keeps after its platform tabs: the
/// page's own secondary actions ([items]) first, then the layout choice and
/// the way to the platform wall — what the wide row draws as its chevron and
/// its layout switch.
final class PlatformToolbarMore extends ConsumerWidget {
  /// The menu; [items] lead it, the layout and the wall follow.
  const PlatformToolbarMore({
    required this.platforms,
    required this.current,
    required this.nameOf,
    required this.onChanged,
    this.onManagePlatforms,
    this.countOf,
    this.items = const [],
    super.key,
  });

  /// The platform ids the wall lists, in order.
  final List<String> platforms;

  /// The selected platform id.
  final String current;

  /// A platform id's display name.
  final String Function(String id) nameOf;

  /// Fired with the id of the platform picked in the wall.
  final ValueChanged<String> onChanged;

  /// Opens the platform-display setting from the wall's header.
  final VoidCallback? onManagePlatforms;

  /// A platform's own count, shown under its name in the wall.
  final int? Function(String id)? countOf;

  /// The page's own menu items, above the shared choices.
  final List<Widget> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final layout = ref.watch(browseLayoutProvider);
    final sites = ref.watch(sitesProvider);
    return DsMenuAnchor(
      semanticLabel: t.common.more,
      align: DsAlign.end,
      items: [
        ...items,
        if (items.isNotEmpty) const DsMenuDivider(),
        DsMenuItem(
          label: Text(t.common.layoutGrid),
          checked: layout == CardLayout.grid,
          onPressed: () => unawaited(ref.read(browseLayoutProvider.notifier).set(CardLayout.grid)),
        ),
        DsMenuItem(
          label: Text(t.common.layoutList),
          checked: layout == CardLayout.list,
          onPressed: () => unawaited(ref.read(browseLayoutProvider.notifier).set(CardLayout.list)),
        ),
        if (platforms.isNotEmpty) ...[
          const DsMenuDivider(),
          DsMenuItem(
            leading: const DsIcon(DsIcons.antenna),
            label: Text(t.common.switchPlatform),
            onPressed: () => unawaited(
              showPlatformPickerPanel(
                context,
                platforms: platforms,
                current: current,
                nameOf: nameOf,
                iconOf: (id) => localizedSiteIcon(sites.getById(id), size: 32),
                onChanged: onChanged,
                onManagePlatforms: onManagePlatforms,
                countOf: countOf,
              ),
            ),
          ),
        ],
      ],
      builder: (context, controller, _) => DsButton.icon(
        variant: DsButtonVariant.ghost,
        size: DsSize.sm,
        semanticLabel: t.common.more,
        onPressed: controller.open,
        icon: const DsIcon(DsIcons.ellipsisVertical),
      ),
    );
  }
}

/// Opens the platform wall: every platform the page offers as a square tile,
/// the platform's own logo over its name, and the shown one marked with a
/// check badge rather than only a tint (the reference's platform wall).
///
/// [PlatformTabRow]'s chevron and the follows page's own tab row both come
/// through here, so the catalogue is one shape wherever it is opened.
/// [countOf] adds a number under each name — the follows page counts what each
/// platform holds there, and its tabs already show it.
Future<void> showPlatformPickerPanel(
  BuildContext context, {
  required List<String> platforms,
  required String current,
  required String Function(String id) nameOf,
  required Widget? Function(String id) iconOf,
  required ValueChanged<String> onChanged,
  VoidCallback? onManagePlatforms,
  int? Function(String id)? countOf,
}) {
  return showDsPanel<void>(
    context: context,
    // auto (the default) is exactly the rule: side on a wide window, bottom
    // on a narrow one.
    detents: const [0.5, 1],
    builder: (context) => _PlatformPanel(
      platforms: platforms,
      current: current,
      nameOf: nameOf,
      iconOf: iconOf,
      onChanged: onChanged,
      onManagePlatforms: onManagePlatforms,
      countOf: countOf,
    ),
  );
}

/// The panel's own body; shown by [showPlatformPickerPanel].
final class _PlatformPanel extends StatelessWidget {
  const _PlatformPanel({
    required this.platforms,
    required this.current,
    required this.nameOf,
    required this.iconOf,
    required this.onChanged,
    required this.onManagePlatforms,
    this.countOf,
  });

  final List<String> platforms;
  final String current;
  final String Function(String id) nameOf;
  final Widget? Function(String id) iconOf;
  final ValueChanged<String> onChanged;
  final VoidCallback? onManagePlatforms;

  /// A platform's own count, when the page has one to show.
  final int? Function(String id)? countOf;

  /// The tile's height: the logo, its name, an optional count and the
  /// breathing room between.
  static const double _tileExtent = 112;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPanel(
      // The header carries the way out to the setting that hides and
      // reorders these entries, beside the panel's own close button: the
      // viewer is looking at the whole catalogue right here.
      title: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(child: Text(t.popular.allPlatforms)),
          if (onManagePlatforms case final manage?)
            DsButton(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.slidersHorizontal, size: 14),
              onPressed: () {
                Navigator.of(context).pop();
                manage();
              },
              child: Text(t.settings.sitesDisplay),
            ),
        ],
      ),
      // The title is a row now, so the panel's name has to be said.
      semanticLabel: t.popular.allPlatforms,
      // The grid scrolls itself; the panel hands it the room it has.
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.popular.allPlatformsHint, style: theme.typography.small.copyWith(color: colors.textMuted)),
          Expanded(
            child: GridView.builder(
              // A focused card's ring is painted 4px outside it, while a
              // viewport clips at its own edge: this room keeps the first
              // and last columns' rings whole instead of cutting them flat
              // against the panel's border.
              padding: const EdgeInsets.all(DsSpace.s6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: _tileExtent,
                mainAxisSpacing: DsSpace.s12,
                crossAxisSpacing: DsSpace.s12,
              ),
              itemCount: platforms.length,
              itemBuilder: (context, index) {
                final id = platforms[index];
                final name = nameOf(id);
                final selected = id == current;
                return DsCard(
                  // A remote opens the panel with no pointer: the shown
                  // platform is the first stop.
                  autofocus: selected,
                  semanticLabel: name,
                  style: DsCardStyle(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s12),
                    background: selected ? colors.accentTint : null,
                  ),
                  onPressed: () {
                    onChanged(id);
                    Navigator.of(context).pop();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: DsSpace.s8,
                        children: [
                          ?iconOf(id),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.typography.small.copyWith(color: colors.text),
                          ),
                          if (countOf?.call(id) case final count?)
                            Text('$count', style: theme.typography.overline.copyWith(color: colors.textSubtle)),
                        ],
                      ),
                      if (selected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: DsBoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(9)),
                            child: DsIcon(DsIcons.check, size: 12, color: colors.onAccent),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A platform tab's label: its name, and the page's count for it when the
/// page has one. One weight throughout, so selecting a tab moves nothing
/// beside it (the kit's own rule for a top nav).
final class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.name, this.count});

  final String name;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    if (count case final count?) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          Text(name),
          Text('$count', style: theme.typography.overline.copyWith(color: theme.colors.textSubtle)),
        ],
      );
    }
    return Text(name);
  }
}
