import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;

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
/// [build] watches the search scope (the page's own platform tabs, not the
/// shell's site), so switching scopes restarts the search surface: the
/// query, its results and even its target reset, and the scope's own
/// `supportedTargets` decide what can be searched at all — every platform
/// at once ("all") searches rooms only, like the reference. The page asks
/// for every search (a submit, a suggestion tap, a target switch) — a
/// notifier never loads from inside its own build. A newer request always
/// wins: answers from a search that was replaced are dropped, not written
/// over the newer one's results.
final class SearchController extends Notifier<SearchState> {
  int _searchGeneration = 0;
  int _suggestGeneration = 0;

  @override
  SearchState build() {
    final scope = ref.watch(searchSiteIdProvider);
    return _initial(_firstTargetOf(scope));
  }

  /// The targets [scope] actually searches, in the canonical rooms,
  /// anchors, areas order; "all" searches rooms only (the reference's
  /// all-platforms scope), one platform the targets it offers.
  List<LiveSearchTarget> supportedTargetsOf(String scope) {
    if (scope == kSearchAllPlatforms) return const [LiveSearchTarget.rooms];
    final offered = ref.read(sitesProvider).getById(scope)?.capability<LiveSearchProvider>()?.supportedTargets ??
        const <LiveSearchTarget>{};
    return [for (final target in LiveSearchTarget.values) if (offered.contains(target)) target];
  }

  /// The target a fresh search starts on: the first one the scope supports,
  /// rooms when it supports none (the page says so instead of asking).
  LiveSearchTarget _firstTargetOf(String scope) {
    final supported = supportedTargetsOf(scope);
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
    if (target == state.target || !supportedTargetsOf(ref.read(searchSiteIdProvider)).contains(target)) {
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
    final scope = ref.read(searchSiteIdProvider);
    if (word.isNotEmpty && scope != kSearchAllPlatforms) {
      final capability = ref.read(sitesProvider).getById(scope)?.capability<LiveSuggestCapability>();
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
    final scope = ref.read(searchSiteIdProvider);
    final site = scope == kSearchAllPlatforms ? null : ref.read(sitesProvider).getById(scope);
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
    final capability = site?.capability<LiveSearchProvider>();
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
          siteId: scope,
          message: capability == null ? 'no search capability' : 'search target ${target.name} not supported',
        ),
        suggestions: state.suggestions,
      );
      return;
    }
    if (site == null) {
      await _loadEverywhere(query: query, target: target, page: page, generation: generation);
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

  /// Searches every search-capable platform at once ("all"): the same page
  /// of each site's rooms, merged in registry order — the reference's
  /// all-platforms search. A platform that fails (an overseas one without a
  /// proxy, say) keeps out of the way: the page shows what answered.
  Future<void> _loadEverywhere({
    required String query,
    required LiveSearchTarget target,
    required int page,
    required int generation,
  }) async {
    final pageSize = ref.read(browseSettingsProvider).homePageSize;
    final candidates = <({LiveSite site, LiveSearchProvider capability})>[
      for (final site in ref.read(sitesProvider).all)
        if (site.capability<LiveSearchProvider>() case final capability?)
          if (capability.supportedTargets.contains(target)) (site: site, capability: capability),
    ];
    final asks = <Future<Either<LiveSiteError, LivePage<LiveSearchResult>>>>[
      for (final candidate in candidates)
        candidate.capability.search(
          LiveSearchRequest.of(query: query, target: target, page: page, pageSize: pageSize),
        ),
    ];
    final answers = await Future.wait(asks);
    if (!ref.mounted || generation != _searchGeneration) return;
    final rooms = <LiveRoom>[];
    final anchors = <LiveAnchor>[];
    final areas = <LiveArea>[];
    var anyMore = false;
    for (final answer in answers) {
      answer.match(
        (_) {},
        (pageAnswer) {
          rooms.addAll(_roomsOf(pageAnswer));
          anchors.addAll(_anchorsOf(pageAnswer));
          areas.addAll(_areasOf(pageAnswer));
          if (pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty) anyMore = true;
        },
      );
    }
    // Nothing at all answered (every platform failed): the error state says
    // so instead of an empty page.
    if (rooms.isEmpty && anchors.isEmpty && areas.isEmpty) {
      state = (
        query: query,
        target: target,
        rooms: state.rooms,
        anchors: state.anchors,
        areas: state.areas,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: const LiveSiteError.network(siteId: kSearchAllPlatforms, message: 'every platform failed'),
        suggestions: state.suggestions,
      );
      return;
    }
    state = (
      query: query,
      target: target,
      rooms: page == 1 ? rooms : [...state.rooms, ...rooms],
      anchors: page == 1 ? anchors : [...state.anchors, ...anchors],
      areas: page == 1 ? areas : [...state.areas, ...areas],
      nextPage: page + 1,
      hasMore: anyMore,
      loading: false,
      error: null,
      suggestions: state.suggestions,
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

/// The scope id meaning "search every platform at once" — the tabs' first
/// entry, like the reference's all-platforms scope.
const String kSearchAllPlatforms = 'all';

/// The search page's shown scope, remembered under `browse.search.site`;
/// every platform ("all") until the viewer narrows it.
final class SearchSiteController extends Notifier<String> {
  @override
  String build() {
    try {
      final stored = StoragePrefs.getString('browse.search.site');
      if (stored != null &&
          (stored == kSearchAllPlatforms || ref.read(sitesProvider).all.any((site) => site.manifest.id == stored))) {
        return stored;
      }
    } on Object {
      // Storage never opened: the default stands.
    }
    return kSearchAllPlatforms;
  }

  /// The shown scope.
  String get selected => state;

  /// Moves the scope, writing the choice through.
  set selected(String id) {
    state = id;
    unawaited(StoragePrefs.setString('browse.search.site', id));
  }
}

/// The search page's shown scope.
final searchSiteIdProvider = NotifierProvider<SearchSiteController, String>(SearchSiteController.new);

/// The search history: the last queries the viewer committed, newest
/// first, kept under `search.history` (the reference stores its history in
/// the same shape), at most ten.
final class SearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() {
    try {
      return StoragePrefs.getStringList('search.history') ?? const <String>[];
    } on Object {
      return const [];
    }
  }

  /// Puts [query] at the history's head, dropping its older self and every
  /// entry past the tenth.
  Future<void> commit(String query) async {
    final word = query.trim();
    if (word.isEmpty) return;
    final next = [word, ...state.where((entry) => entry != word)].take(10).toList();
    state = next;
    try {
      await StoragePrefs.setStringList('search.history', next);
    } on Object {
      // The history is a nicety; a closed store loses it, nothing else.
    }
  }

  /// Drops one entry.
  Future<void> remove(String query) async {
    final next = state.where((entry) => entry != query).toList();
    state = next;
    try {
      await StoragePrefs.setStringList('search.history', next);
    } on Object {
      // Same nicety as commit.
    }
  }

  /// Drops every entry.
  Future<void> clear() async {
    state = const [];
    try {
      await StoragePrefs.setStringList('search.history', const []);
    } on Object {
      // Same nicety as commit.
    }
  }
}

/// The search history.
final searchHistoryProvider = NotifierProvider<SearchHistoryController, List<String>>(SearchHistoryController.new);
