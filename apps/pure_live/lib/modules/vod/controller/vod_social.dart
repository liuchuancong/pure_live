import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_vod/live_vod.dart';

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

/// The seasons the signed-in viewer follows: type 1 is 番剧, 2 is 影视.
final FutureProviderFamily<VodSeasonPage, int> vodFollowingSeasonsProvider = FutureProvider.family<VodSeasonPage, int>((
  ref,
  type,
) async {
  final account = await ref.watch(vodAccountProvider.future);
  final mid = account.mid;
  if (!account.isLogin || mid == null) return const VodSeasonPage(seasons: [], hasMore: false);
  return await ref.watch(vodClientProvider).followingSeasons(mid: mid, type: type);
});

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
  VodDynamicsState build() => _dynamicsInitial();

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
  VodFailure? error,
});

VodCommentsState _commentsInitial() =>
    (comments: const [], total: 0, nextPage: 1, hasMore: true, loading: false, error: null);

/// The comments under an archive, cached per aid and paged by demand.
final class VodCommentsController extends Notifier<Map<int, VodCommentsState>> {
  @override
  Map<int, VodCommentsState> build() => const {};

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

  /// Reads the first page again (the retry button).
  Future<void> refresh(int aid) => _load(aid, 1);

  Future<void> _load(int aid, int page) async {
    final current = of(aid);
    if (current.loading) return;
    state = {...state, aid: _with(current, loading: true, clearError: true)};
    try {
      final answer = await ref.read(vodClientProvider).comments(aid, page: page);
      if (!ref.mounted) return;
      final open = state[aid];
      if (open == null) return;
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
          error: null,
        ),
      };
    } on Object catch (failure) {
      if (!ref.mounted) return;
      final open = state[aid];
      if (open == null) return;
      state = {
        ...state,
        aid: _with(
          open,
          loading: false,
          hasMore: false,
          error: failure is VodFailure ? failure : VodFailure(failure.toString()),
        ),
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
    VodFailure? error,
    bool clearError = false,
  }) => (
    comments: comments ?? from.comments,
    total: total ?? from.total,
    nextPage: nextPage ?? from.nextPage,
    hasMore: hasMore ?? from.hasMore,
    loading: loading ?? from.loading,
    error: clearError ? null : (error ?? from.error),
  );
}

/// The archives' comments.
final vodCommentsProvider = NotifierProvider<VodCommentsController, Map<int, VodCommentsState>>(
  VodCommentsController.new,
);
