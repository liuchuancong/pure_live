import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/favorite_rules.dart';
import 'package:pure_live/modules/live/favorites/data/favorites_refresh_handoff.dart';
import 'package:pure_live/modules/live/favorites/data/favorites_view.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/shared/shared.dart';

/// The follows page's verbs in the phone's top bar: the platform menu and the
/// refresh, drawn as the outlined buttons the page's own toolbar uses.
///
/// The page keeps its tabs line alone on a phone; these two live up here so
/// the refresh is offered once and the more glyph is a button beside it.
final class FavoritesTopBarActions extends ConsumerWidget {
  /// Creates the actions.
  const FavoritesTopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final view = ref.watch(favoritesViewProvider);
    final tabs = followPlatformTabs(follows.rooms, ref.read(sitesDisplayProvider.notifier).visibleIds());
    final platform = tabs.contains(view.platform) ? view.platform : kAllPlatforms;
    String nameOf(String id) {
      if (id == kAllPlatforms) return t.favorites.statusAll;
      final site = ref.read(sitesProvider).getById(id);
      return site == null ? id : localizedSiteName(site);
    }

    // Search, refresh, more — the order the bar reads from its start.
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        DsButton.icon(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          semanticLabel: t.favorites.refresh,
          onPressed: () => ref.read(followsPageRefreshProvider.notifier).run(),
          icon: const DsIcon(DsIcons.refreshCw, size: 16),
        ),
        PlatformToolbarMore(
          platforms: [kAllPlatforms, ...tabs],
          current: platform,
          nameOf: nameOf,
          countOf: (id) => followCount(follows.rooms, platform: id == kAllPlatforms ? null : id, group: view.group),
          onChanged: ref.read(favoritesViewProvider.notifier).selectPlatform,
          onManagePlatforms: () =>
              unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location)),
        ),
      ],
    );
  }
}
