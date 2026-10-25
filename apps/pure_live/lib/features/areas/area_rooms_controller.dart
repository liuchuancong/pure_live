import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/shared/paging/room_paging.dart';

/// What an area-rooms page holds: the open area, every room fetched so far,
/// the desktop page shown over them and its size.
typedef AreaRoomsState = ({
  LiveSite site,
  LiveArea area,
  List<LiveRoom> rooms,
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
final class AreaRoomsController extends Notifier<AreaRoomsState?> {
  RoomWalk? _walk;
  Set<String> _seen = {};

  @override
  AreaRoomsState? build() => null;

  /// Opens [area] on [site] and asks for its first rooms. A second call
  /// while the same area is open is a no-op — the page's re-init on hot
  /// reloads must not restart the feed.
  Future<void> init({required LiveSite site, required LiveArea area}) async {
    final current = state;
    if (current != null && current.site == site && current.area == area) return;
    _walk = null;
    _seen = {};
    final pageSize = ref.read(browseSettingsProvider).homePageSize;
    state = (
      site: site,
      area: area,
      rooms: const [],
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
    final failure = await fillRoomFeed(walk: walk, rooms: rooms, seen: seen, target: current.pageSize);
    final open = state;
    if (open == null || open.area != current.area) return;
    if (failure != null) {
      state = _with(open, loading: false, error: failure);
      return;
    }
    _walk = walk;
    _seen = seen;
    state = (
      site: open.site,
      area: open.area,
      rooms: List.unmodifiable(rooms),
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
    final seen = _seen.isEmpty ? {for (final room in current.rooms) room.identityKey} : _seen;
    final rooms = [...current.rooms];
    state = _with(current, loading: true, clearError: true);
    // Each fetched page lands at once: a later failure keeps the rooms and
    // the walk stays on the page that failed, so nothing is stranded.
    void publishProgress() {
      _seen = seen;
      state = (
        site: current.site,
        area: current.area,
        rooms: List.unmodifiable(rooms),
        page: math.min(page, roomLastPage(rooms.length, current.pageSize)),
        pageSize: current.pageSize,
        hasMore: walk.hasMore,
        loading: true,
        error: null,
      );
    }

    final failure = await fillRoomFeed(
      walk: walk,
      rooms: rooms,
      seen: seen,
      target: target,
      onProgress: publishProgress,
    );
    final open = state;
    if (open == null || open.area != current.area) return;
    if (failure != null) {
      state = _with(open, loading: false, error: failure);
      return;
    }
    _seen = seen;
    final last = roomLastPage(rooms.length, open.pageSize);
    final shown = walk.hasMore ? page : math.min(page, last);
    state = (
      site: open.site,
      area: open.area,
      rooms: List.unmodifiable(rooms),
      page: shown,
      pageSize: open.pageSize,
      hasMore: walk.hasMore,
      loading: false,
      error: null,
    );
  }

  AreaRoomsState _with(
    AreaRoomsState from, {
    List<LiveRoom>? rooms,
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
