import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, selectedSiteProvider;

/// What the search page holds: the committed query, the target it runs on,
/// that search's typed results, where the next page asks, the in-flight
/// flag, and the site's completions for the field's current draft.
typedef SearchState = ({
  String query,
  LiveSearchTarget target,
  List<LiveRoom> rooms,
  List<LiveAnchor> anchors,
  List<LiveArea> areas,
  int nextPage,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
  List<String> suggestions,
});

SearchState _initial(LiveSearchTarget target) => (
  query: '',
  target: target,
  rooms: const [],
  anchors: const [],
  areas: const [],
  nextPage: 1,
  hasMore: true,
  loading: false,
  error: null,
  suggestions: const [],
);

/// The search page's state and requests, paged by scroll like the home feed.
///
/// [build] watches the selected site, so switching sites restarts the search
/// surface: the query, its results and even its target reset, and the new
/// site's own `supportedTargets` decide what can be searched at all. The
/// page asks for every search (a submit, a suggestion tap, a target switch)
/// — a notifier never loads from inside its own build. A newer request
/// always wins: answers from a search that was replaced are dropped, not
/// written over the newer one's results.
final class SearchController extends Notifier<SearchState> {
  int _searchGeneration = 0;
  int _suggestGeneration = 0;

  @override
  SearchState build() {
    ref.watch(selectedSiteIdProvider);
    return _initial(_firstTargetOf(ref.read(selectedSiteProvider)));
  }

  /// The targets [site] actually searches, in the canonical rooms, anchors,
  /// areas order; empty when the site has no search at all.
  static List<LiveSearchTarget> supportedTargetsOf(LiveSite site) {
    final offered = site.capability<LiveSearchProvider>()?.supportedTargets ?? const <LiveSearchTarget>{};
    return [for (final target in LiveSearchTarget.values) if (offered.contains(target)) target];
  }

  /// The target a fresh search starts on: the first one the site supports,
  /// rooms when the site supports none (the page says so instead of asking).
  static LiveSearchTarget _firstTargetOf(LiveSite site) {
    final supported = supportedTargetsOf(site);
    return supported.isEmpty ? LiveSearchTarget.rooms : supported.first;
  }

  /// Searches [query] from its first page; a blank query clears the search.
  Future<void> search(String query) {
    final word = query.trim();
    if (word.isEmpty) {
      _searchGeneration++;
      state = _initial(state.target);
      return Future.value();
    }
    return _load(query: word, target: state.target, page: 1);
  }

  /// Loads the next page of the current query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(query: state.query, target: state.target, page: state.nextPage);
  }

  /// Runs the current query again from its first page (the retry button).
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(query: state.query, target: state.target, page: 1);
  }

  /// Moves the search to [target]; a committed query is searched there
  /// again, so a switch never shows one target's results under another
  /// one's tab. A target the site does not search is ignored — the page
  /// never offers one.
  Future<void> switchTarget(LiveSearchTarget target) {
    if (target == state.target || !supportedTargetsOf(ref.read(selectedSiteProvider)).contains(target)) {
      return Future.value();
    }
    if (state.query.isEmpty) {
      state = _initial(target);
      return Future.value();
    }
    return _load(query: state.query, target: target, page: 1);
  }

  /// Stores the site's completions for the field's [draft].
  ///
  /// The page debounces its typing before calling this; a newer call always
  /// wins, and a site without the capability (or a failed round trip)
  /// answers empty — suggestions are a nicety, never an error state.
  Future<void> suggest(String draft) async {
    final word = draft.trim();
    final generation = ++_suggestGeneration;
    var completions = const <String>[];
    if (word.isNotEmpty) {
      final capability = ref.read(selectedSiteProvider).capability<LiveSuggestCapability>();
      if (capability != null) {
        try {
          completions = await capability.suggestions(word);
        } on Object {
          completions = const [];
        }
      }
    }
    if (!ref.mounted || generation != _suggestGeneration) return;
    state = (
      query: state.query,
      target: state.target,
      rooms: state.rooms,
      anchors: state.anchors,
      areas: state.areas,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: state.loading,
      error: state.error,
      suggestions: completions,
    );
  }

  Future<void> _load({required String query, required LiveSearchTarget target, required int page}) async {
    final generation = ++_searchGeneration;
    final site = ref.read(selectedSiteProvider);
    state = (
      query: query,
      target: target,
      rooms: page == 1 ? const [] : state.rooms,
      anchors: page == 1 ? const [] : state.anchors,
      areas: page == 1 ? const [] : state.areas,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
      suggestions: page == 1 ? const [] : state.suggestions,
    );
    final capability = site.capability<LiveSearchProvider>();
    if (capability == null || !capability.supportedTargets.contains(target)) {
      state = (
        query: query,
        target: target,
        rooms: state.rooms,
        anchors: state.anchors,
        areas: state.areas,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: LiveSiteError.unsupported(
          siteId: site.manifest.id,
          message: capability == null ? 'no search capability' : 'search target ${target.name} not supported',
        ),
        suggestions: state.suggestions,
      );
      return;
    }
    final answer = await capability.search(
      LiveSearchRequest.of(
        query: query,
        target: target,
        page: page,
        pageSize: ref.read(browseSettingsProvider).homePageSize,
      ),
    );
    // A search that was replaced (a newer query, target or site) drains its
    // answer without writing it.
    if (!ref.mounted || generation != _searchGeneration) return;
    answer.match(
      (error) => state = (
        query: query,
        target: target,
        rooms: state.rooms,
        anchors: state.anchors,
        areas: state.areas,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: error,
        suggestions: state.suggestions,
      ),
      (pageAnswer) => state = (
        query: query,
        target: target,
        rooms: [...state.rooms, ..._roomsOf(pageAnswer)],
        anchors: [...state.anchors, ..._anchorsOf(pageAnswer)],
        areas: [...state.areas, ..._areasOf(pageAnswer)],
        nextPage: page + 1,
        hasMore: pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty,
        loading: false,
        error: null,
        suggestions: state.suggestions,
      ),
    );
  }

  /// The room hits of [page] — the ones a rooms search answered.
  static List<LiveRoom> _roomsOf(LivePage<LiveSearchResult> page) => [
    for (final hit in page.items)
      if (hit case RoomSearchResult(:final room)) room,
  ];

  /// The anchor hits of [page] — the ones an anchors search answered.
  static List<LiveAnchor> _anchorsOf(LivePage<LiveSearchResult> page) => [
    for (final hit in page.items)
      if (hit case AnchorSearchResult(:final anchor)) anchor,
  ];

  /// The area hits of [page] — the ones an areas search answered.
  static List<LiveArea> _areasOf(LivePage<LiveSearchResult> page) => [
    for (final hit in page.items)
      if (hit case AreaSearchResult(:final area)) area,
  ];
}

/// The search page's state.
final searchProvider = NotifierProvider<SearchController, SearchState>(SearchController.new);
