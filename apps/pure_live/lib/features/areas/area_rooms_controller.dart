import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';

/// What an area-rooms page holds: the open area and the rooms shown so far
/// with where the next page asks.
typedef AreaRoomsState = ({
  LiveSite site,
  LiveArea area,
  List<LiveRoom> rooms,
  int nextPage,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
});

/// One open area's rooms feed: the same paging contract as the home feed —
/// the page asks for the first rooms and every next page, the controller
/// never loads from inside its own build.
///
/// A stale answer (the page moved to another area) is dropped, so an old
/// area's rooms never land under a new area's title.
final class AreaRoomsController extends Notifier<AreaRoomsState?> {
  @override
  AreaRoomsState? build() => null;

  /// Opens [area] on [site] and asks for its first page. A second call
  /// while the same area is open is a no-op — the page's re-init on hot
  /// reloads must not restart the feed.
  Future<void> init({required LiveSite site, required LiveArea area}) async {
    final current = state;
    if (current != null && current.site == site && current.area == area) return;
    state = (site: site, area: area, rooms: const [], nextPage: 1, hasMore: true, loading: false, error: null);
    await _load(page: 1);
  }

  /// Loads the first page again (a retry from the error state).
  Future<void> reload() => _load(page: 1);

  /// Loads the next page when one is left.
  Future<void> loadMore() {
    final current = state;
    if (current != null && !current.loading && current.hasMore) {
      return _load(page: current.nextPage);
    }
    return Future.value();
  }

  Future<void> _load({required int page}) async {
    final current = state;
    if (current == null || current.loading) return;
    state = _with(current, loading: true, clearError: true);
    final capability = current.site.capability<LiveAreaProvider>();
    if (capability == null) {
      _set(
        current,
        rooms: current.rooms,
        hasMore: false,
        error: LiveSiteError.unsupported(siteId: current.site.manifest.id, message: 'no area capability'),
      );
      return;
    }
    final answer = await capability.getAreaRooms(
      area: current.area,
      request: LivePageRequest.of(page: page, pageSize: ref.read(browseSettingsProvider).homePageSize),
    );
    // The open area may have changed while the page was in flight.
    final open = state;
    if (open == null || open.area != current.area) return;
    answer.match(
      (error) => _set(current, rooms: open.rooms, error: error),
      (pageAnswer) => _set(
        current,
        rooms: page == 1 ? pageAnswer.items.toList() : [...open.rooms, ...pageAnswer.items],
        nextPage: page + 1,
        hasMore: pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty,
      ),
    );
  }

  AreaRoomsState _with(
    AreaRoomsState from, {
    List<LiveRoom>? rooms,
    int? nextPage,
    bool? hasMore,
    bool? loading,
    LiveSiteError? error,
    bool clearError = false,
  }) {
    return (
      site: from.site,
      area: from.area,
      rooms: rooms ?? from.rooms,
      nextPage: nextPage ?? from.nextPage,
      hasMore: hasMore ?? from.hasMore,
      loading: loading ?? from.loading,
      error: clearError ? null : (error ?? from.error),
    );
  }

  /// Publishes the result of a finished page against [from], guarding
  /// against the page having moved on in the meantime.
  void _set(
    AreaRoomsState from, {
    List<LiveRoom>? rooms,
    int? nextPage,
    bool? hasMore,
    LiveSiteError? error,
  }) {
    final open = state;
    if (open == null || open.area != from.area) return;
    state = _with(open, rooms: rooms, nextPage: nextPage, hasMore: hasMore, loading: false, error: error, clearError: error == null);
  }
}

/// The open area's rooms; null until a page opens one.
final areaRoomsProvider = NotifierProvider<AreaRoomsController, AreaRoomsState?>(AreaRoomsController.new);
