import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, selectedSiteProvider;

/// What the home feed holds: the rooms shown so far and where the next
/// page asks.
typedef HomeFeedState = ({
  List<LiveRoom> rooms,
  int nextPage,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
});

HomeFeedState _initial() => (rooms: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// The home page's recommended-rooms feed, paged by scroll.
///
/// [build] watches the selected site, so switching sites restarts the feed
/// from its first page: the old site's rooms never linger under the new
/// one's header. The page asks for the first page (and every next one) —
/// a notifier never loads from inside its own build.
final class HomeFeedController extends Notifier<HomeFeedState> {
  @override
  HomeFeedState build() {
    ref.watch(selectedSiteIdProvider);
    return _initial();
  }

  /// Loads the feed's first page (the first show and every retry).
  Future<void> reload() => _load(page: 1);

  /// Loads the next page when one is left.
  Future<void> loadMore() {
    if (!state.loading && state.hasMore) return _load(page: state.nextPage);
    return Future.value();
  }

  Future<void> _load({required int page}) async {
    if (state.loading) return;
    state = (rooms: state.rooms, nextPage: state.nextPage, hasMore: state.hasMore, loading: true, error: null);
    final site = ref.read(selectedSiteProvider);
    final discovery = site.capability<LiveDiscoveryProvider>();
    if (discovery == null) {
      state = (
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: LiveSiteError.unsupported(siteId: site.manifest.id, message: 'no discovery capability'),
      );
      return;
    }
    final answer = await discovery.getRecommendedRooms(
      request: LivePageRequest.of(page: page, pageSize: ref.read(browseSettingsProvider).homePageSize),
    );
    answer.match(
      (error) => state = (rooms: state.rooms, nextPage: state.nextPage, hasMore: false, loading: false, error: error),
      (pageAnswer) => state = (
        rooms: page == 1
            ? pageAnswer.items.toList()
            : [...state.rooms, ...pageAnswer.items],

        nextPage: page + 1,
        hasMore: pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty,
        loading: false,
        error: null,
      ),
    );
  }
}

/// The home feed's state.
final homeFeedProvider = NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);
