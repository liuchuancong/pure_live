import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;

/// What the vod page holds: the committed query, its videos, where the next
/// page asks, the in-flight flag, and the last failure.
typedef VodState = ({String query, List<VodVideo> videos, int nextPage, bool hasMore, bool loading, VodFailure? error});

VodState _initial() => (query: '', videos: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// The vod source's client over the shared transport.
///
/// One pipeline serves the whole module — the `api` profile fits Bilibili's
/// fixed endpoints (bounded retries, caching only where a call opts in) —
/// and the transport stays behind [LiveHttp], so proxies and cookies remain
/// the app shell's business.
final vodClientProvider = Provider<BilibiliVodClient>((ref) {
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  ref.onDispose(http.close);
  return BilibiliVodClient(http);
});

/// The vod page's state and requests, paged by scroll like the home feed.
///
/// The vod source only searches — it offers no regions, rankings or
/// recommendations to browse — so the page commits a keyword and pages its
/// hits; with no keyword there is nothing to load, and the page says so
/// instead of asking. A newer query always wins: an answer from a search
/// that was replaced drains without writing. The page asks for every load —
/// a notifier never loads from inside its own build.
final class VodController extends Notifier<VodState> {
  int _generation = 0;

  @override
  VodState build() => _initial();

  /// Searches [query] from its first page; a blank query clears the results.
  Future<void> search(String query) {
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = _initial();
      return Future.value();
    }
    return _load(word, 1);
  }

  /// Loads the next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(state.query, state.nextPage);
  }

  /// Runs the committed query again from its first page (the retry button).
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, 1);
  }

  Future<void> _load(String query, int page) async {
    final generation = ++_generation;
    state = (
      query: query,
      videos: page == 1 ? const [] : state.videos,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final answer = await ref
          .read(vodClientProvider)
          .search(query, page: page, pageSize: ref.read(browseSettingsProvider).homePageSize);
      // A search that was replaced (a newer query) drains its answer
      // without writing it.
      if (!ref.mounted || generation != _generation) return;
      state = (
        query: query,
        videos: page == 1 ? answer.videos : [...state.videos, ...answer.videos],
        nextPage: page + 1,
        hasMore: answer.hasMore,
        loading: false,
        error: null,
      );
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        query: query,
        videos: state.videos,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: failure is VodFailure ? failure : VodFailure(failure.toString()),
      );
    }
  }
}

/// The vod page's state.
final vodProvider = NotifierProvider<VodController, VodState>(VodController.new);
