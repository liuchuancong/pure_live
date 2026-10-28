import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/app.dart';

/// What the station's live page holds: the rooms fetched so far, the page
/// the next ask names, and whether the site says more follow.
typedef VodLiveFeed = ({List<LiveRoom> rooms, int nextPage, bool hasMore, bool loading, LiveSiteError? error});

const VodLiveFeed _emptyLiveFeed = (rooms: [], nextPage: 1, hasMore: true, loading: false, error: null);

/// The reference's 直播 rail entry: Bilibili's recommended live rooms, one
/// page at a time. The pile stays while the app runs, so leaving the page and
/// coming back does not re-ask the first page.
final class VodLiveController extends Notifier<VodLiveFeed> {
  static const int _pageSize = 30;

  @override
  VodLiveFeed build() => _emptyLiveFeed;

  /// Loads the first page when nothing is held (the page asks on open).
  Future<void> open() async {
    if (state.rooms.isNotEmpty || state.loading) return;
    await _load(1);
  }

  /// Loads the next page when one is left.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.rooms.isEmpty) return;
    await _load(state.nextPage);
  }

  /// Asks page 1 again, replacing the pile.
  Future<void> refresh() async {
    if (state.loading) return;
    await _load(1);
  }

  Future<void> _load(int page) async {
    final discovery = ref.read(sitesProvider).getById(SiteIds.bilibili)?.capability<LiveDiscoveryProvider>();
    if (discovery == null) {
      state = (
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: const LiveSiteError.unsupported(siteId: SiteIds.bilibili, message: 'no discovery capability'),
      );
      return;
    }
    state = (
      rooms: page == 1 ? const <LiveRoom>[] : state.rooms,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    final answer = await discovery.getRecommendedRooms(
      request: LivePageRequest.of(page: page, pageSize: _pageSize),
    );
    answer.match(
      (failure) => state = (rooms: state.rooms, nextPage: page, hasMore: state.hasMore, loading: false, error: failure),
      (result) {
        final rooms = page == 1 ? <LiveRoom>[] : [...state.rooms];
        final seen = {for (final room in rooms) room.ref.identityKey};
        rooms.addAll([
          for (final room in result.items)
            if (seen.add(room.ref.identityKey)) room,
        ]);
        state = (
          rooms: List<LiveRoom>.unmodifiable(rooms),
          nextPage: page + 1,
          hasMore: result.hasMore ?? result.items.isNotEmpty,
          loading: false,
          error: null,
        );
      },
    );
  }
}

/// The station's recommended live rooms.
final vodLiveProvider = NotifierProvider<VodLiveController, VodLiveFeed>(VodLiveController.new);

/// The site's browsable areas, for the live page's area strip. A failed ask
/// leaves the strip away rather than failing the page.
final vodLiveAreasProvider = FutureProvider<List<LiveArea>>((ref) async {
  final areas = ref.read(sitesProvider).getById(SiteIds.bilibili)?.capability<LiveAreaProvider>();
  if (areas == null) return const [];
  final answer = await areas.getAreas();
  return answer.match<List<LiveArea>>((_) => const <LiveArea>[], (areas) => areas);
});
