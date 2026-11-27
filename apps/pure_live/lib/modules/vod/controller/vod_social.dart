import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart';

import 'package:pure_live/features/account/account_providers.dart' show accountsProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// The viewer Bilibili's nav endpoint sees. A guest is a normal answer rather
/// than a failure: the pages that need a sign-in read `isLogin` and show the
/// invitation, because being signed out at Bilibili is not an error here.
final vodAccountProvider = FutureProvider<VodAccount>((ref) => ref.watch(vodClientProvider).account());

/// The signed-in viewer's 稍后再看 list.
final FutureProvider<List<VodVideo>> vodWatchLaterProvider = FutureProvider<List<VodVideo>>((ref) async {
  final account = await ref.watch(vodAccountProvider.future);
  if (!account.isLogin) return const [];
  return await ref.watch(vodClientProvider).watchLater();
});

/// The seasons the signed-in viewer follows, paged by the shelf's scroll.
typedef VodFollowingState = ({
  List<VodSeason> seasons,
  int nextPage,
  bool hasMore,
  bool loading,
  bool loaded,
  VodFailure? error,
});

VodFollowingState _followingInitial() =>
    (seasons: const [], nextPage: 1, hasMore: true, loading: false, loaded: false, error: null);

/// One 追番 shelf. The account change starts a new shelf, so a late page from
/// the previous viewer never lands in the current one.
final class VodFollowingController extends Notifier<VodFollowingState> {
  VodFollowingController(this.type);

  /// The station's shelf type: 1 番剧, 2 影视.
  final int type;

  int _generation = 0;

  @override
  VodFollowingState build() {
    ref.watch(accountsProvider.select((accounts) => accounts.credentials[SiteIds.bilibili]?.userId));
    _generation++;
    return _followingInitial();
  }

  /// Loads the first page when the shelf has not been read.
  Future<void> open() async {
    if (state.loaded || state.loading) return;
    await _load(1);
  }

  /// Loads the next page when the station says one follows.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || !state.loaded) return;
    await _load(state.nextPage);
  }

  /// Reads the shelf again from its first page.
  Future<void> refresh() => _load(1);

  Future<void> _load(int page) async {
    final generation = ++_generation;
    state = (
      seasons: page == 1 ? const [] : state.seasons,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      loaded: state.loaded,
      error: null,
    );
    try {
      final account = await ref.read(vodAccountProvider.future);
      final mid = account.mid;
      if (!account.isLogin || mid == null) {
        if (!ref.mounted || generation != _generation) return;
        state = (seasons: const [], nextPage: 1, hasMore: false, loading: false, loaded: true, error: null);
        return;
      }
      final answer = await ref.read(vodClientProvider).followingSeasons(mid: mid, type: type, page: page);
      if (!ref.mounted || generation != _generation) return;
      final seasons = page == 1 ? <VodSeason>[] : [...state.seasons];
      if (page > 1) {
        final seen = {for (final season in seasons) season.seasonId};
        seasons.addAll(answer.seasons.where((season) => seen.add(season.seasonId)));
      } else {
        seasons.addAll(answer.seasons);
      }
      state = (
        seasons: seasons,
        nextPage: page + 1,
        hasMore: answer.hasMore && answer.seasons.isNotEmpty,
        loading: false,
        loaded: true,
        error: null,
      );
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        seasons: state.seasons,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        loaded: true,
        error: failure is VodFailure ? failure : VodFailure(failure.toString()),
      );
    }
  }
}

/// The viewer's 追番 shelves, one controller per station type.
final NotifierProviderFamily<VodFollowingController, VodFollowingState, int> vodFollowingProvider =
    NotifierProvider.family<VodFollowingController, VodFollowingState, int>(VodFollowingController.new);

/// The dynamic feed's state: the posts read so far, the cursor for the next
/// page, and the in-flight flag.
typedef VodDynamicsState = ({
  List<VodDynamic> items,
  String? offset,
  bool hasMore,
  bool loading,
  bool loaded,
  VodFailure? error,
});

VodDynamicsState _dynamicsInitial() =>
    (items: const [], offset: null, hasMore: true, loading: false, loaded: false, error: null);

/// The signed-in viewer's dynamic feed, cursored: each page asks with the
/// cursor the last one answered, and the feed ends when the answer says so.
final class VodDynamicsController extends Notifier<VodDynamicsState> {
  int _generation = 0;

  @override
  VodDynamicsState build() {
    // The feed is read as one viewer: signing in, signing out or switching
    // accounts makes what was loaded someone else's answer, so the controller
    // starts over and the page's next ask reads it again with the new cookie.
    ref.watch(accountsProvider.select((accounts) => accounts.credentials[SiteIds.bilibili]?.userId));
    _generation++;
    return _dynamicsInitial();
  }

  /// Loads the first page when the feed is empty and idle; the page asks.
  Future<void> open() async {
    if (state.loaded || state.loading) return;
    await _load(null);
  }

  /// Loads the next page when the answer said there is one.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || !state.loaded) return;
    await _load(state.offset);
  }

  /// Reads the feed again from its first page.
  Future<void> refresh() => _load(null);

  Future<void> _load(String? offset) async {
    final generation = ++_generation;
    state = (
      items: offset == null ? const [] : state.items,
      offset: state.offset,
      hasMore: state.hasMore,
      loading: true,
      loaded: state.loaded,
      error: null,
    );
    try {
      final page = await ref.read(vodClientProvider).dynamics(offset: offset);
      if (!ref.mounted || generation != _generation) return;
      final items = offset == null ? page.items : [...state.items];
      if (offset != null) {
        final seen = {for (final item in items) item.id};
        items.addAll(page.items.where((item) => seen.add(item.id)));
      }
      state = (
        items: items,
        offset: page.offset,
        // A page that repeats the cursor would walk in place.
        hasMore: page.hasMore && page.offset != null && page.offset != offset,
        loading: false,
        loaded: true,
        error: null,
      );
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        items: state.items,
        offset: state.offset,
        hasMore: false,
        loading: false,
        loaded: true,
        error: failure is VodFailure ? failure : VodFailure(failure.toString()),
      );
    }
  }
}

/// The viewer's dynamic feed.
final vodDynamicsProvider = NotifierProvider<VodDynamicsController, VodDynamicsState>(VodDynamicsController.new);

/// One archive's comment page state.
typedef VodCommentsState = ({
  List<VodComment> comments,
  int total,
  int nextPage,
  bool hasMore,
  bool loading,
  int sort,
  VodFailure? error,
});

VodCommentsState _commentsInitial() =>
    (comments: const [], total: 0, nextPage: 1, hasMore: true, loading: false, sort: 1, error: null);

/// The comments under an archive, cached per aid and paged by demand.
final class VodCommentsController extends Notifier<Map<int, VodCommentsState>> {
  /// The orders the comments read in: Bilibili's 最热 and 最新.
  static const int sortHot = 1;
  static const int sortNewest = 2;

  int _generation = 0;
  final Map<int, int> _requests = {};

  @override
  Map<int, VodCommentsState> build() {
    ref.watch(vodClientProvider);
    _generation++;
    _requests.clear();
    return const {};
  }

  /// The comments of [aid], or the empty page before they are read.
  VodCommentsState of(int aid) => state[aid] ?? _commentsInitial();

  /// Reads [aid]'s first page when it has none and nothing is in flight.
  Future<void> open(int aid) async {
    final comments = of(aid);
    if (comments.comments.isNotEmpty || comments.loading) return;
    await _load(aid, 1);
  }

  /// Reads the next page when one is left.
  Future<void> loadMore(int aid) async {
    final comments = of(aid);
    if (comments.loading || !comments.hasMore) return;
    await _load(aid, comments.nextPage);
  }

  /// Reads the first page again as a manual refresh.
  Future<void> refresh(int aid) => _load(aid, 1);

  /// Retries the page that failed without discarding earlier comments.
  Future<void> retry(int aid) => _load(aid, of(aid).nextPage);

  /// Reads [aid]'s comments in [sort] order, from the first page.
  Future<void> setSort(int aid, int sort) async {
    final comments = of(aid);
    if (comments.sort == sort || comments.loading) return;
    state = {
      ...state,
      aid: _with(comments, sort: sort, comments: const [], nextPage: 1, hasMore: true, clearError: true),
    };
    await _load(aid, 1);
  }

  Future<void> _load(int aid, int page) async {
    final current = of(aid);
    if (current.loading) return;
    final sort = current.sort;
    final generation = ++_generation;
    _requests[aid] = generation;
    state = {...state, aid: _with(current, loading: true, clearError: true)};
    try {
      final answer = await ref.read(vodClientProvider).comments(aid, page: page, sort: sort);
      if (!ref.mounted || _requests[aid] != generation) return;
      final open = state[aid];
      if (open == null || open.sort != sort) return;
      final comments = page == 1 ? answer.comments : [...open.comments];
      if (page > 1) {
        final seen = {for (final comment in comments) comment.id};
        comments.addAll(answer.comments.where((comment) => seen.add(comment.id)));
      }
      state = {
        ...state,
        aid: (
          comments: comments,
          total: answer.total,
          nextPage: page + 1,
          // A page that brought nothing new ends the walk.
          hasMore: answer.hasMore && (page == 1 || comments.length > open.comments.length),
          loading: false,
          sort: sort,
          error: null,
        ),
      };
    } on Object catch (failure) {
      if (!ref.mounted || _requests[aid] != generation) return;
      final open = state[aid];
      if (open == null || open.sort != sort) return;
      state = {
        ...state,
        aid: _with(open, loading: false, error: failure is VodFailure ? failure : VodFailure(failure.toString())),
      };
    }
  }

  VodCommentsState _with(
    VodCommentsState from, {
    List<VodComment>? comments,
    int? total,
    int? nextPage,
    bool? hasMore,
    bool? loading,
    int? sort,
    VodFailure? error,
    bool clearError = false,
  }) => (
    comments: comments ?? from.comments,
    total: total ?? from.total,
    nextPage: nextPage ?? from.nextPage,
    hasMore: hasMore ?? from.hasMore,
    loading: loading ?? from.loading,
    sort: sort ?? from.sort,
    error: clearError ? null : (error ?? from.error),
  );
}

/// The archives' comments.
final vodCommentsProvider = NotifierProvider<VodCommentsController, Map<int, VodCommentsState>>(
  VodCommentsController.new,
);

// ---- The signed-in viewer's verdicts (the write surface) ----

/// Whether the bilibili cookie can speak the write endpoints: the pasted
/// credential carries the csrf token (`bili_jct`). The access-key session —
/// the app scan sign-in — is a different credential model these web
/// endpoints do not take, and the pages keep their read-only shape for it.
final vodWriteReadyProvider = Provider<bool>((ref) => ref.watch(vodClientProvider).canWrite);

/// One archive's like verdict: whether the signed-in viewer's like stands.
/// A guest reads null — the action row keeps its read-only shape — and the
/// verdict is read as one viewer, the credential changing starting it over.
final class VodLikeController extends Notifier<bool?> {
  VodLikeController(this.aid);

  /// The archive the verdict speaks of.
  final int aid;

  int _generation = 0;
  bool _writing = false;

  @override
  bool? build() {
    ref.watch(accountsProvider.select((accounts) => accounts.credentials[SiteIds.bilibili]?.userId));
    _generation++;
    _writing = false;
    final client = ref.read(vodClientProvider);
    if (!client.canWrite) return null;
    unawaited(_read(client, ++_generation));
    return null;
  }

  Future<void> _read(BilibiliVodClient client, int generation) async {
    try {
      final liked = await client.hasLiked(aid: aid);
      // A flip that landed while the read was under way owns the state.
      if (!ref.mounted || state != null || generation != _generation) return;
      state = liked;
    } on Object {
      // The read failing leaves the pill a fact, not a failure.
    }
  }

  /// Flips the viewer's like: the flip lands at once, and the endpoint's
  /// refusal puts it back and rethrows for the page's toast.
  Future<void> toggle() async {
    if (_writing) return;
    _writing = true;
    final generation = ++_generation;
    final next = !(state ?? false);
    state = next;
    try {
      await ref.read(vodClientProvider).setLike(aid: aid, like: next);
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = !next;
      rethrow;
    } finally {
      if (generation == _generation) _writing = false;
    }
  }
}

/// One archive's like verdict.
final NotifierProviderFamily<VodLikeController, bool?, int> vodLikeProvider =
    NotifierProvider.family<VodLikeController, bool?, int>(VodLikeController.new);

/// One uploader's follow verdict: whether the signed-in viewer follows them.
/// A guest reads null — the uploader row keeps its door without the chip.
final class VodFollowUpController extends Notifier<bool?> {
  VodFollowUpController(this.mid);

  /// The uploader the verdict speaks of.
  final int mid;

  int _generation = 0;
  bool _writing = false;

  @override
  bool? build() {
    ref.watch(accountsProvider.select((accounts) => accounts.credentials[SiteIds.bilibili]?.userId));
    _generation++;
    _writing = false;
    final client = ref.read(vodClientProvider);
    if (!client.canWrite) return null;
    unawaited(_read(client, ++_generation));
    return null;
  }

  Future<void> _read(BilibiliVodClient client, int generation) async {
    try {
      final followed = await client.isFollowing(mid: mid);
      // A flip that landed while the read was under way owns the state.
      if (!ref.mounted || state != null || generation != _generation) return;
      state = followed;
    } on Object {
      // The read failing leaves the chip without a verdict, not broken.
      if (!ref.mounted || generation != _generation) return;
      state = null;
    }
  }

  /// Flips the viewer's follow: the flip lands at once, and the endpoint's
  /// refusal puts it back and rethrows for the page's toast.
  Future<void> toggle() async {
    if (_writing) return;
    _writing = true;
    final generation = ++_generation;
    final next = !(state ?? false);
    state = next;
    try {
      await ref.read(vodClientProvider).setFollowing(mid: mid, follow: next);
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = !next;
      rethrow;
    } finally {
      if (generation == _generation) _writing = false;
    }
  }
}

/// One uploader's follow verdict.
final NotifierProviderFamily<VodFollowUpController, bool?, int> vodFollowUpProvider =
    NotifierProvider.family<VodFollowUpController, bool?, int>(VodFollowUpController.new);
