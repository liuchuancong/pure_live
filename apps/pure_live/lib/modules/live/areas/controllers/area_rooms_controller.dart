import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/shared/shared.dart';

/// What an area-rooms page holds: the open area, every room fetched so far,
/// the desktop page shown over them, its size, and how many of the fetched
/// rooms the viewer's discovery filter hides.
typedef AreaRoomsState = ({
  LiveSite site,
  LiveArea area,
  List<LiveRoom> rooms,
  int hidden,
  int page,
  int pageSize,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
});

/// One open area's rooms feed: the home feed's own contract — the page asks
/// for the first rooms and every next page, the controller never loads from
/// inside its own build, and a stale answer (the page moved to another
/// area) is dropped.
///
/// The walk asks the platform's own request window (`areaRequestSize`) with
/// its cursor where it has one and dedupes across pages; the desktop pager
/// slices the accumulated rooms locally, so fixed 120-room pages (Douyu)
/// and 30-room ones page the same way.
///
/// Rooms that cannot play here stay out of the shown list unless the
/// viewer shows them (the reference's `showUnplayableInDiscover`), but they
/// stay in the fetched catalogue: the filter is re-applied in place, never
/// by asking the platform again.
final class AreaRoomsController extends Notifier<AreaRoomsState?> {
  RoomWalk? _walk;
  Set<String> _seen = {};

  /// Every room fetched, hidden ones included (the reference's
  /// `RoomFeed.allRooms`).
  List<LiveRoom> _fullRooms = const [];

  /// Whether [room] belongs on the page as the settings stand: the
  /// reference's `cannotPlayHere` rule, with a stored credential making a
  /// 需要登录/成年 room playable.
  bool _playable(LiveRoom room) {
    if (ref.read(showUnplayableProvider)) return true;
    final signedIn = ref.read(accountsProvider).credentials.containsKey(room.ref.platform);
    return !cannotPlayHere(room, signedIn: signedIn);
  }

  List<LiveRoom> _visibleOf(List<LiveRoom> full) => [for (final room in full) if (_playable(room)) room];

  @override
  AreaRoomsState? build() {
    // The filter answer and the sign-ins live outside this controller: a
    // change re-runs the rule over the fetched rooms at once (the
    // reference's setting listener + `visibilityChanged`).
    ref
      ..listen(showUnplayableProvider, (_, _) => _refreshVisibility())
      ..listen(accountsProvider, (_, _) => _refreshVisibility());
    return null;
  }

  /// Opens [area] on [site] and asks for its first rooms. A second call
  /// while the same area is open is a no-op — the page's re-init on hot
  /// reloads must not restart the feed.
  Future<void> init({required LiveSite site, required LiveArea area}) async {
    final current = state;
    if (current != null && current.site == site && current.area == area) return;
    _walk = null;
    _seen = {};
    _fullRooms = const [];
    // One display page is one of the platform's own area windows: the pager
    // follows the site rather than a setting the viewer no longer has.
    final pageSize = areaRequestSize(site.manifest.id);
    state = (
      site: site,
      area: area,
      rooms: const [],
      hidden: 0,
      page: 1,
      pageSize: pageSize,
      hasMore: true,
      loading: false,
      error: null,
    );
    await _reload();
  }

  /// Loads the catalogue again from page 1 (pull to refresh, retry). A
  /// failure keeps the old rooms on screen.
  Future<void> reload() => _reload();

  /// Loads at least one more room for the endless list; a chunk is shown
  /// whole.
  Future<void> loadMore() async {
    final current = state;
    if (current == null || current.loading || !current.hasMore || current.rooms.isEmpty) return;
    await _fill(target: current.rooms.length + 1, page: current.page);
  }

  /// Shows [page] of the catalogue, fetching only when the slice is not
  /// already in hand.
  Future<void> loadPage(int page) async {
    final current = state;
    if (current == null || page < 1 || current.loading) return;
    final target = page * current.pageSize;
    if (current.rooms.length >= target || !current.hasMore) {
      final last = roomLastPage(current.rooms.length, current.pageSize);
      final shown = current.hasMore ? page : math.min(page, last);
      state = _with(current, page: shown);
      return;
    }
    await _fill(target: target, page: page);
  }

  /// Re-measures the catalogue in [pageSize] rooms per page, keeping the
  /// first room of the shown page in view.
  Future<void> resize(int pageSize) async {
    final current = state;
    if (current == null || pageSize < 1 || current.pageSize == pageSize || current.loading) return;
    final first = (current.page - 1) * current.pageSize;
    final requested = first ~/ pageSize + 1;
    final last = roomLastPage(current.rooms.length, pageSize);
    final page = current.hasMore ? requested : math.min(requested, last);
    state = _with(current, page: page, pageSize: pageSize);
    if (current.rooms.length >= page * pageSize || !current.hasMore) return;
    await _fill(target: page * pageSize, page: page);
  }

  Future<void> _reload() async {
    final current = state;
    if (current == null || current.loading) return;
    final capability = current.site.capability<LiveAreaProvider>();
    if (capability == null) {
      state = _with(
        current,
        hasMore: false,
        error: LiveSiteError.unsupported(siteId: current.site.manifest.id, message: 'no area capability'),
      );
      return;
    }
    final walk = RoomWalk(
      fetch: (request) => capability.getAreaRooms(area: current.area, request: request),
      pageSize: areaRequestSize(current.site.manifest.id),
    );
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    state = _with(current, loading: true, clearError: true, page: 1);
    final failure = await _collect(walk: walk, rooms: rooms, seen: seen, target: current.pageSize);
    final open = state;
    if (open == null || open.area != current.area) return;
    if (failure != null) {
      state = _with(open, loading: false, error: failure);
      return;
    }
    _walk = walk;
    _seen = seen;
    _fullRooms = List.unmodifiable(rooms);
    final visible = _visibleOf(rooms);
    state = (
      site: open.site,
      area: open.area,
      rooms: List.unmodifiable(visible),
      hidden: rooms.length - visible.length,
      page: 1,
      pageSize: current.pageSize,
      hasMore: walk.hasMore,
      loading: false,
      error: null,
    );
  }

  Future<void> _fill({required int target, required int page}) async {
    final current = state;
    if (current == null || current.loading) return;
    final capability = current.site.capability<LiveAreaProvider>();
    if (capability == null) {
      state = _with(
        current,
        hasMore: false,
        error: LiveSiteError.unsupported(siteId: current.site.manifest.id, message: 'no area capability'),
      );
      return;
    }
    final walk = _walk ??= RoomWalk(
      fetch: (request) => capability.getAreaRooms(area: current.area, request: request),
      pageSize: areaRequestSize(current.site.manifest.id),
    );
    final seen = _seen.isEmpty ? {for (final room in _fullRooms) room.identityKey} : _seen;
    final rooms = [..._fullRooms];
    state = _with(current, loading: true, clearError: true);
    // Each fetched page lands at once: a later failure keeps the rooms and
    // the walk stays on the page that failed, so nothing is stranded.
    void publishProgress() {
      _seen = seen;
      _fullRooms = List.unmodifiable(rooms);
      final visible = _visibleOf(rooms);
      state = (
        site: current.site,
        area: current.area,
        rooms: List.unmodifiable(visible),
        hidden: rooms.length - visible.length,
        page: math.min(page, roomLastPage(visible.length, current.pageSize)),
        pageSize: current.pageSize,
        hasMore: walk.hasMore,
        loading: true,
        error: null,
      );
    }

    final failure = await _collect(
      walk: walk,
      rooms: rooms,
      seen: seen,
      target: target,
      onProgress: publishProgress,
    );
    final open = state;
    if (open == null || open.area != current.area) return;
    if (failure != null) {
      _fullRooms = List.unmodifiable(rooms);
      final visible = _visibleOf(rooms);
      state = _with(
        open,
        rooms: List.unmodifiable(visible),
        hidden: rooms.length - visible.length,
        loading: false,
        error: failure,
      );
      return;
    }
    _seen = seen;
    _fullRooms = List.unmodifiable(rooms);
    final visible = _visibleOf(rooms);
    final last = roomLastPage(visible.length, open.pageSize);
    final shown = walk.hasMore ? page : math.min(page, last);
    state = (
      site: open.site,
      area: open.area,
      rooms: List.unmodifiable(visible),
      hidden: rooms.length - visible.length,
      page: shown,
      pageSize: open.pageSize,
      hasMore: walk.hasMore,
      loading: false,
      error: null,
    );
  }

  /// Fetches from [walk] until [target] rooms pass the discovery filter,
  /// the walk ends, or twenty pages were asked (the reference's
  /// `RoomFeed.maxRequests`). [rooms] holds every fetched room; [seen]
  /// dedupes across calls. Answers the failure that stopped the walk.
  Future<LiveSiteError?> _collect({
    required RoomWalk walk,
    required List<LiveRoom> rooms,
    required Set<String> seen,
    required int target,
    void Function()? onProgress,
  }) async {
    var requests = 0;
    var visible = rooms.where(_playable).length;
    while (visible < target && walk.hasMore && requests < 20) {
      final answer = await walk.next(seen);
      final failure = answer.fold<LiveSiteError?>((error) => error, (fresh) {
        rooms.addAll(fresh);
        visible += fresh.where(_playable).length;
        return null;
      });
      if (failure != null) return failure;
      // Each page is handed over before the next is asked, so a later
      // failure never strands rooms the walk has already moved past.
      onProgress?.call();
      requests++;
    }
    return null;
  }

  /// Re-applies the discovery filter to the fetched rooms (the setting
  /// changed, or a sign-in altered the login part).
  void _refreshVisibility() {
    final current = state;
    if (current == null) return;
    final visible = _visibleOf(_fullRooms);
    final last = roomLastPage(visible.length, current.pageSize);
    final page = current.hasMore ? current.page : math.min(current.page, last);
    state = _with(
      current,
      rooms: List.unmodifiable(visible),
      hidden: _fullRooms.length - visible.length,
      page: page,
    );
  }

  AreaRoomsState _with(
    AreaRoomsState from, {
    List<LiveRoom>? rooms,
    int? hidden,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loading,
    LiveSiteError? error,
    bool clearError = false,
  }) {
    return (
      site: from.site,
      area: from.area,
      rooms: rooms ?? from.rooms,
      hidden: hidden ?? from.hidden,
      page: page ?? from.page,
      pageSize: pageSize ?? from.pageSize,
      hasMore: hasMore ?? from.hasMore,
      loading: loading ?? from.loading,
      error: clearError ? null : (error ?? from.error),
    );
  }
}

/// The open area's rooms; null until a page opens one.
final areaRoomsProvider = NotifierProvider<AreaRoomsController, AreaRoomsState?>(AreaRoomsController.new);
