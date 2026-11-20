import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/favorites/data/favorite_rules.dart'
    show followCount, followGroupCounts, followGroupOf, onFollowPlatform;
import 'package:pure_live/modules/live/favorites/data/favorites_inline_search.dart'
    show favoritesInlineSearchProvider, followMatchesQuery;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/shared/shared.dart' show kAllPlatforms;

/// The follows page's own choices: the group tab, the platform tab and
/// the tag chip.
///
/// They live above the page because the phone's top bar offers the platform
/// menu and the refresh; the bar has to know which platform the page is on
/// and which one a pick should show.
typedef FavoritesView = ({LiveFollowGroup? group, String platform, String? tag});

/// The follows view, shared by the page and the phone's top bar.
final class FavoritesViewController extends Notifier<FavoritesView> {
  @override
  // The page opens on the rooms on air: the group a viewer follows for is
  // "what is live now", and 全部 opened on a wall of dark rooms first.
  FavoritesView build() => (group: LiveFollowGroup.live, platform: kAllPlatforms, tag: null);

  /// Shows [group]; a new group is a new slice of the follows.
  void selectGroup(LiveFollowGroup? group) {
    if (state.group == group) return;
    state = (group: group, platform: state.platform, tag: state.tag);
  }

  /// Shows [platform]; a new platform is a new slice of the follows.
  void selectPlatform(String platform) {
    if (state.platform == platform) return;
    state = (group: state.group, platform: platform, tag: state.tag);
  }

  /// Shows [tag]; a tag is a further cut of the group and platform slices.
  void selectTag(String? tag) {
    if (state.tag == tag) return;
    state = (group: state.group, platform: state.platform, tag: tag);
  }
}

/// The follows page's rooms under the view's three cuts and the toolbar's
/// word, derived once per change — the page reads a finished list instead of
/// re-running the filter chain on every build. A tag the tag list no longer
/// holds cuts nothing: the view's remembered id dies with its tag, the way
/// the page's own chip fallback already reads it — otherwise removing a
/// selected tag empties the page under the viewer.
final favoritesListedRoomsProvider = Provider<List<LiveRoom>>((ref) {
  final view = ref.watch(favoritesViewProvider);
  final rooms = ref.watch(followsProvider).rooms;
  final query = (ref.watch(favoritesInlineSearchProvider) ?? '').toLowerCase();
  final tag = ref.watch(followTagsProvider).any((entry) => entry.id == view.tag) ? view.tag : null;
  final scope = _activePlatformOf(view, rooms);
  return [
    for (final room in rooms)
      if (onFollowPlatform(room, scope == kAllPlatforms ? null : scope) &&
          (view.group == null || followGroupOf(room) == view.group) &&
          (tag == null || room.local.tagIds.contains(tag)) &&
          followMatchesQuery(room, query))
        room,
  ];
});

/// The view's platform as the page shows it: a platform whose last follow
/// left reads 全部, the way the page's own tab fallback reads it — the tabs
/// stop naming the platform the moment its rooms are gone, and a list cut
/// by the remembered name would sit empty under an 全部 tab.
String _activePlatformOf(FavoritesView view, List<LiveRoom> rooms) {
  if (view.platform == kAllPlatforms) return kAllPlatforms;
  final present = rooms.any((room) => room.ref.platform == view.platform);
  return present ? view.platform : kAllPlatforms;
}

/// The group tabs' counts under the view's platform, derived likewise.
final favoritesGroupCountsProvider = Provider<Map<LiveFollowGroup, int>>((ref) {
  final view = ref.watch(favoritesViewProvider);
  final rooms = ref.watch(followsProvider).rooms;
  final scope = _activePlatformOf(view, rooms);
  return followGroupCounts(rooms, scope == kAllPlatforms ? null : scope);
});

/// The whole count the page's head shows under the view's platform.
final favoritesTotalProvider = Provider<int>((ref) {
  final view = ref.watch(favoritesViewProvider);
  final rooms = ref.watch(followsProvider).rooms;
  final scope = _activePlatformOf(view, rooms);
  return followCount(rooms, platform: scope == kAllPlatforms ? null : scope);
});

/// The follows page's group and platform, as the page and the bar read them.
final favoritesViewProvider = NotifierProvider<FavoritesViewController, FavoritesView>(FavoritesViewController.new);
