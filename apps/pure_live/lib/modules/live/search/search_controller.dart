import 'dart:async' show TimeoutException, unawaited;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either, left;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/live/search/search_capability.dart' show SearchCapabilities;
import 'package:pure_live/modules/live/search/search_scope.dart' show searchExcludedProvider;
import 'package:pure_live/shared/shared.dart';

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

/// How long one platform may take for one search page (the reference's
/// `liveSearchRequestTimeout`); a platform that misses it is skipped instead
/// of holding the whole search open.
const Duration _searchRequestTimeout = Duration(seconds: 12);

/// TwitCasting refuses a keyword past its own limit; the reference cuts it
/// before asking, so a long share text still searches instead of failing.
const int _twitcastingKeywordLimit = 100;

String _queryFor(String siteId, String query) => siteId == 'twitcasting' && query.length > _twitcastingKeywordLimit
    ? query.substring(0, _twitcastingKeywordLimit)
    : query;

/// The search page's state and requests, paged by scroll like the home feed.
///
/// [build] watches the search scope (the page's own platform tabs, not the
/// shell's site), so switching scopes restarts the search surface: the
/// query, its results and even its target reset, and the scope's own
/// `supportedTargets` decide what can be searched at all — every platform
/// at once ("all") searches rooms and, where a platform can answer them,
/// streamers; one platform offers the targets it declares. The page asks
/// for every search (a submit, a suggestion tap, a target switch) — a
/// notifier never loads from inside its own build. A newer request always
/// wins: answers from a search that was replaced are dropped, not written
/// over the newer one's results.
final class SearchController extends Notifier<SearchState> {
  int _searchGeneration = 0;
  int _suggestGeneration = 0;

  /// Search pages in a row that brought no new result; two end the walk
  /// (the reference's `maxConsecutiveStagnantSearchPages`).
  int _stagnant = 0;

  /// Cancels an in-flight [ensureResultsFor] loop when a newer search
  /// starts; the loop must never append an old query's pages to it.
  int _ensureToken = 0;

  /// The fill in flight: one page-filling walk at a time, so a page jump
  /// and an endless list cannot ask the same server page twice.
  Future<void>? _fill;

  /// Per platform in an "all" search: whether another page may follow, and
  /// its streak of unchanged pages (search answers often overlap by one).
  final Map<String, bool> _everywhereMore = {};
  final Map<String, int> _everywhereStagnant = {};

  /// The platforms that failed while this "all" search ran; the page's
  /// banner names them until a later page or retry answers.
  final Set<String> _everywhereFailed = <String>{};

  /// The room each anchor hit names, when its platform's answer carried one;
  /// the anchor card opens that room instead of the profile page.
  final Map<String, String> _anchorRooms = <String, String>{};

  @override
  SearchState build() {
    final scope = ref.watch(searchSiteIdProvider);
    _ensureToken++;
    _resetWalks();
    return _initial(_firstTargetOf(scope));
  }

  void _resetWalks() {
    _stagnant = 0;
    _everywhereMore.clear();
    _everywhereStagnant.clear();
  }

  /// The targets [scope] actually searches, in the canonical rooms,
  /// anchors, areas order; "all" searches rooms everywhere and streamers
  /// where a platform can answer them, one platform the targets it offers.
  List<LiveSearchTarget> supportedTargetsOf(String scope) {
    if (scope == kSearchAllPlatforms) {
      final excluded = ref.read(searchExcludedProvider);
      final nativeTls = ref.read(nativeTlsPlatformsProvider);
      final anchors = ref
          .read(sitesProvider)
          .all
          .where(
            (site) =>
                !excluded.contains(site.manifest.id) &&
                !SiteFacts.isRetired(site.manifest.id) &&
                (!SiteFacts.requiresNativeTls.contains(site.manifest.id) || nativeTls.contains(site.manifest.id)),
          )
          .any(
            (site) =>
                site.capability<LiveSearchProvider>()?.supportedTargets.contains(LiveSearchTarget.anchors) ?? false,
          );
      // "All" searches rooms everywhere and streamers where a platform can
      // answer them, as the reference's all-platforms scope does.
      return [LiveSearchTarget.rooms, if (anchors) LiveSearchTarget.anchors];
    }
    final offered =
        ref.read(sitesProvider).getById(scope)?.capability<LiveSearchProvider>()?.supportedTargets ??
        const <LiveSearchTarget>{};
    return [
      for (final target in LiveSearchTarget.values)
        if (offered.contains(target)) target,
    ];
  }

  /// The target a fresh search starts on: the first one the scope supports,
  /// rooms when it supports none (the page says so instead of asking).
  LiveSearchTarget _firstTargetOf(String scope) {
    final supported = supportedTargetsOf(scope);
    return supported.isEmpty ? LiveSearchTarget.rooms : supported.first;
  }

  /// Searches [query] from its first page; a blank query clears the search.
  Future<void> search(String query) {
    _ensureToken++;
    final word = query.trim();
    if (word.isEmpty) {
      _searchGeneration++;
      _resetWalks();
      state = _initial(state.target);
      return Future.value();
    }
    return _load(query: word, target: state.target, page: 1);
  }

  /// Loads the next page of the current query when one is left.
  Future<void> loadMore() {
    if (_fill != null || state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(query: state.query, target: state.target, page: state.nextPage);
  }

  /// Fetches server pages until the results hold enough for a desktop page
  /// [page] of [pageSize] hits, or the walk ends.
  ///
  /// The viewer's page size is a display slice here, never a server page
  /// size: the search keeps asking its next server page, so jumping pages
  /// never moves a platform's page boundaries. The caller slices the
  /// accumulated rooms and owns the page number.
  Future<void> ensureResultsFor({required int page, required int pageSize}) async {
    // A second ask (another jump, a size change) joins the fill in flight
    // and re-checks its own target once that one is done.
    while (_fill != null) {
      await _fill;
    }
    if (state.query.isEmpty || page < 1 || pageSize < 1 || state.loading) return;
    final target = page * pageSize;
    if (state.rooms.length >= target || !state.hasMore) return;
    final token = ++_ensureToken;
    late final Future<void> task;
    task = _fillTo(token, target).whenComplete(() {
      if (identical(_fill, task)) _fill = null;
    });
    _fill = task;
    await task;
  }

  /// Appends server pages until [target] hits are held, the walk ends, or
  /// twenty pages were asked. The page size stays the search's own window;
  /// the caller measures its display pages over the result.
  Future<void> _fillTo(int token, int target) async {
    var requests = 0;
    while (state.rooms.length < target && state.hasMore && requests < 20) {
      if (token != _ensureToken) return;
      final before = state.rooms.length;
      await _load(query: state.query, target: state.target, page: state.nextPage);
      if (token != _ensureToken) return;
      requests++;
      if (state.rooms.length == before && !state.hasMore) break;
    }
  }

  /// Runs the current query again from its first page (the retry button).
  Future<void> retry() {
    _ensureToken++;
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
    _ensureToken++;
    if (state.query.isEmpty) {
      _resetWalks();
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
    // The call continues the current walk, or jumps (the pager) and
    // replaces the page whole.
    final replace = page == 1 || page != state.nextPage;
    final scope = ref.read(searchSiteIdProvider);
    final site = scope == kSearchAllPlatforms ? null : ref.read(sitesProvider).getById(scope);
    if (replace) {
      _stagnant = 0;
      ref.read(searchFailuresProvider.notifier).clear();
      _everywhereFailed.clear();
      _anchorRooms.clear();
      ref.read(anchorRoomsProvider.notifier).set(const <String, String>{});
      if (site == null) {
        _everywhereMore.clear();
        _everywhereStagnant.clear();
      }
    }
    state = (
      query: query,
      target: target,
      rooms: replace ? const [] : state.rooms,
      anchors: replace ? const [] : state.anchors,
      areas: replace ? const [] : state.areas,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
      suggestions: replace ? const [] : state.suggestions,
    );
    // "All" has no site of its own: every search-capable platform answers
    // its own page (see [_loadEverywhere]). Asking a null site for a
    // capability would have made the all-platform scope answer "no search
    // capability" before it ever fanned out.
    if (site == null) {
      await _loadEverywhere(query: query, target: target, page: page, generation: generation, replace: replace);
      return;
    }
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
          siteId: scope,
          message: capability == null ? 'no search capability' : 'search target ${target.name} not supported',
        ),
        suggestions: state.suggestions,
      );
      return;
    }
    // A fixed request window: a viewer's display page size never moves a
    // server page boundary mid-search (the reference's search page size).
    Either<LiveSiteError, LivePage<LiveSearchResult>> answer;
    try {
      answer = await capability
          .search(
            LiveSearchRequest.of(
              query: _queryFor(site.manifest.id, query),
              target: target,
              page: page,
              pageSize: searchRequestSize,
            ),
          )
          .timeout(_searchRequestTimeout);
    } on TimeoutException catch (error) {
      answer = left(LiveSiteError.network(siteId: site.manifest.id, message: 'search timed out', cause: error));
    } on Object catch (error) {
      answer = left(LiveSiteError.network(siteId: site.manifest.id, message: '$error', cause: error));
    }
    // A search that was replaced (a newer query, target or site) drains its
    // answer without writing it.
    if (!ref.mounted || generation != _searchGeneration) return;
    answer.match(
      (error) {
        ref.read(searchFailuresProvider.notifier).set({site.manifest.id});
        state = (
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
        );
      },
      (pageAnswer) {
        ref.read(searchFailuresProvider.notifier).clear();
        final before = state.rooms.length + state.anchors.length + state.areas.length;
        final rooms = replace
            ? _mergeRooms(const [], _roomsOf(pageAnswer))
            : _mergeRooms(state.rooms, _roomsOf(pageAnswer));
        final anchors = replace
            ? _mergeAnchors(const [], _anchorsOf(pageAnswer))
            : _mergeAnchors(state.anchors, _anchorsOf(pageAnswer));
        final areas = replace
            ? _mergeAreas(const [], _areasOf(pageAnswer))
            : _mergeAreas(state.areas, _areasOf(pageAnswer));
        final added = rooms.length + anchors.length + areas.length - before;
        final stagnant = added == 0 && !replace ? _stagnant + 1 : 0;
        _stagnant = stagnant;
        state = (
          query: query,
          target: target,
          rooms: rooms,
          anchors: anchors,
          areas: areas,
          nextPage: page + 1,
          // A page that repeated itself is given one more chance, then the
          // walk ends; a platform whose adapter has one page ends at once.
          hasMore:
              SearchCapabilities.of(site.manifest.id).paged &&
              (pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty) &&
              stagnant < 2,
          loading: false,
          error: null,
          suggestions: state.suggestions,
        );
      },
    );
  }

  /// Searches every search-capable platform at once ("all"): the same page
  /// of each site's rooms, merged in registry order — the reference's
  /// all-platforms search. A platform that fails (an overseas one without a
  /// proxy, say) keeps out of the way: the page shows what answered, and
  /// every platform's own walk is asked only while it may have more.
  Future<void> _loadEverywhere({
    required String query,
    required LiveSearchTarget target,
    required int page,
    required int generation,
    required bool replace,
  }) async {
    final visible = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final excluded = ref.read(searchExcludedProvider);
    final all = <({LiveSite site, LiveSearchProvider capability})>[
      for (final site in ref.read(sitesProvider).all)
        if (visible.contains(site.manifest.id) && !excluded.contains(site.manifest.id))
          if (site.capability<LiveSearchProvider>() case final capability?)
            if (capability.supportedTargets.contains(target)) (site: site, capability: capability),
    ];
    if (replace) {
      for (final candidate in all) {
        final id = candidate.site.manifest.id;
        _everywhereMore[id] = true;
        _everywhereStagnant[id] = 0;
      }
    }
    final candidates = [
      for (final candidate in all)
        if (replace || (_everywhereMore[candidate.site.manifest.id] ?? true)) candidate,
    ];
    if (candidates.isEmpty) {
      // Every platform's walk ended: nothing more to ask for the old list.
      state = (
        query: query,
        target: target,
        rooms: state.rooms,
        anchors: state.anchors,
        areas: state.areas,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: null,
        suggestions: state.suggestions,
      );
      return;
    }
    // Bounded fan-out: a few platforms in flight at a time, each worker
    // taking the next platform as it finishes. Every answer is merged the
    // moment it arrives, so a slow platform no longer holds the whole page.
    const maxConcurrent = 8;
    var succeeded = false;
    var next = 0;

    void apply(String id, Either<LiveSiteError, LivePage<LiveSearchResult>> answer) {
      if (!ref.mounted || generation != _searchGeneration) return;
      answer.match(
        (_) {
          _everywhereMore[id] = false;
          _everywhereFailed.add(id);
          ref.read(searchFailuresProvider.notifier).set(_everywhereFailed);
        },
        (pageAnswer) {
          succeeded = true;
          _everywhereFailed.remove(id);
          final before = state.rooms.length + state.anchors.length + state.areas.length;
          final rooms = _mergeRooms(state.rooms, _roomsOf(pageAnswer));
          final anchors = _mergeAnchors(state.anchors, _anchorsOf(pageAnswer));
          final areas = _mergeAreas(state.areas, _areasOf(pageAnswer));
          final added = rooms.length + anchors.length + areas.length - before;
          final stagnant = added == 0 ? (_everywhereStagnant[id] ?? 0) + 1 : 0;
          _everywhereStagnant[id] = stagnant;
          _everywhereMore[id] =
              SearchCapabilities.of(id).paged && (pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty) && stagnant < 2;
          state = (
            query: query,
            target: target,
            rooms: rooms,
            anchors: anchors,
            areas: areas,
            nextPage: state.nextPage,
            hasMore: state.hasMore,
            loading: true,
            error: null,
            suggestions: state.suggestions,
          );
          ref.read(searchFailuresProvider.notifier).set(_everywhereFailed);
        },
      );
    }

    Future<void> ask() async {
      while (true) {
        final index = next++;
        if (index >= candidates.length) return;
        final candidate = candidates[index];
        final id = candidate.site.manifest.id;
        Either<LiveSiteError, LivePage<LiveSearchResult>> answer;
        try {
          answer = await candidate.capability
              .search(
                LiveSearchRequest.of(
                  query: _queryFor(id, query),
                  target: target,
                  page: page,
                  pageSize: searchRequestSize,
                ),
              )
              .timeout(_searchRequestTimeout);
        } on TimeoutException catch (error) {
          answer = left(LiveSiteError.network(siteId: id, message: 'search timed out', cause: error));
        } on Object catch (error) {
          answer = left(LiveSiteError.network(siteId: id, message: '$error', cause: error));
        }
        apply(id, answer);
      }
    }

    await Future.wait([for (var worker = 0; worker < math.min(maxConcurrent, candidates.length); worker++) ask()]);
    if (!ref.mounted || generation != _searchGeneration) return;
    // Nothing at all answered (every platform failed): the error state says
    // so instead of an empty page.
    if (!succeeded) {
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
      rooms: state.rooms,
      anchors: state.anchors,
      areas: state.areas,
      nextPage: page + 1,
      hasMore: _everywhereMore.values.any((more) => more),
      loading: false,
      error: null,
      suggestions: state.suggestions,
    );
  }

  /// Merges [incoming] into [current] by identity, keeping first-seen
  /// order — search endpoints overlap pages by one, so a repeated hit is
  /// dropped instead of shown twice.
  static List<LiveRoom> _mergeRooms(List<LiveRoom> current, Iterable<LiveRoom> incoming) {
    final seen = {for (final room in current) room.identityKey};
    return [
      ...current,
      for (final room in incoming)
        if (seen.add(room.identityKey)) room,
    ];
  }

  /// Anchor identity: the platform's uid, e.g. `bilibili:123`.
  static String _anchorKey(LiveAnchor anchor) => searchAnchorKey(anchor);

  /// Merges [incoming] anchors into [current] by identity.
  static List<LiveAnchor> _mergeAnchors(List<LiveAnchor> current, Iterable<LiveAnchor> incoming) {
    final seen = {for (final anchor in current) _anchorKey(anchor)};
    return [
      ...current,
      for (final anchor in incoming)
        if (seen.add(_anchorKey(anchor))) anchor,
    ];
  }

  /// Merges [incoming] areas into [current] by identity.
  static List<LiveArea> _mergeAreas(List<LiveArea> current, Iterable<LiveArea> incoming) {
    final seen = {for (final area in current) area.identityKey};
    return [
      ...current,
      for (final area in incoming)
        if (seen.add(area.identityKey)) area,
    ];
  }

  /// The room hits of [page] — the ones a rooms search answered.
  static List<LiveRoom> _roomsOf(LivePage<LiveSearchResult> page) => [
    for (final hit in page.items)
      if (hit case RoomSearchResult(:final room)) room,
  ];

  /// The anchor hits of [page] — the ones an anchors search answered.
  List<LiveAnchor> _anchorsOf(LivePage<LiveSearchResult> page) {
    final anchors = <LiveAnchor>[];
    var learned = false;
    for (final hit in page.items) {
      if (hit case AnchorSearchResult(:final anchor, :final roomId)) {
        anchors.add(anchor);
        if (roomId != null && roomId.trim().isNotEmpty) {
          _anchorRooms[searchAnchorKey(anchor)] = roomId.trim();
          learned = true;
        }
      }
    }
    if (learned) ref.read(anchorRoomsProvider.notifier).set(Map.of(_anchorRooms));
    return anchors;
  }

  /// The area hits of [page] — the ones an areas search answered.
  static List<LiveArea> _areasOf(LivePage<LiveSearchResult> page) => [
    for (final hit in page.items)
      if (hit case AreaSearchResult(:final area)) area,
  ];
}

/// The identity an anchor's search hit is keyed by; the room map and the
/// merge both use it.
String searchAnchorKey(LiveAnchor anchor) =>
    '${anchor.platform}:${anchor.anchorId.isEmpty ? anchor.name : anchor.anchorId}';

/// The platforms a search asked that answered with a failure; the page
/// names them and offers a retry instead of hiding the partial result.
final class SearchFailuresController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Replaces the failed set.
  void set(Set<String> ids) => state = Set.unmodifiable(ids);

  /// Forgets the last search's failures.
  void clear() => state = const <String>{};
}

/// The platforms that failed in the current search.
final searchFailuresProvider = NotifierProvider<SearchFailuresController, Set<String>>(SearchFailuresController.new);

/// The room id behind each anchor hit, keyed by [searchAnchorKey]; the card
/// opens it when present, the profile page otherwise.
final class AnchorRoomsController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const <String, String>{};

  /// Replaces the learned rooms.
  void set(Map<String, String> rooms) => state = Map.unmodifiable(rooms);
}

/// The rooms the anchor hits name.
final anchorRoomsProvider = NotifierProvider<AnchorRoomsController, Map<String, String>>(AnchorRoomsController.new);

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
/// first, kept under `search.history`, at most twenty (the reference's
/// limit), each cut to the same length its share texts are.
final class SearchHistoryController extends Notifier<List<String>> {
  /// How many words are kept.
  static const int limit = 20;

  /// The longest word kept; longer share texts are cut, not refused.
  static const int maxLength = 200;

  @override
  List<String> build() {
    try {
      return _clean(StoragePrefs.getStringList('search.history') ?? const <String>[]);
    } on Object {
      return const [];
    }
  }

  /// Puts [query] at the history's head, moving an equal word (case
  /// ignored) up rather than duplicating it.
  Future<void> commit(String query) async {
    final word = query.trim();
    if (word.isEmpty) return;
    final next = _clean([word, ...state]);
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

  static List<String> _clean(Iterable<String> words) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final raw in words) {
      final word = _cut(raw.trim());
      if (word.isEmpty || !seen.add(word.toLowerCase())) continue;
      cleaned.add(word);
      if (cleaned.length == limit) break;
    }
    return cleaned;
  }

  static String _cut(String word) => word.length <= maxLength ? word : word.substring(0, maxLength);
}

/// The search history.
final searchHistoryProvider = NotifierProvider<SearchHistoryController, List<String>>(SearchHistoryController.new);

/// A word handed to the search page from outside (the toolbar's field):
/// the page takes it on arrival — submitting it and recording the
/// history — and clears it, so a back-and-fororth never replays it.
final class PendingSearchController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Hands [word] to the next search page (taken once on arrival).
  // ignore: use_setters_to_change_properties
  void hand(String word) => state = word;

  /// Takes the word (null when none was handed).
  String? take() {
    final word = state;
    state = null;
    return word;
  }
}

/// The word the next search page should run.
final pendingSearchProvider = NotifierProvider<PendingSearchController, String?>(PendingSearchController.new);
