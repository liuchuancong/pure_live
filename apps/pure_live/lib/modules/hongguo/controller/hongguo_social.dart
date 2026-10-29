import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;

import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoFailureText;
import 'package:pure_live/modules/hongguo/official/hongguo_comments.dart' show HongguoComment, HongguoCommentClient;
import 'package:pure_live/modules/hongguo/official/hongguo_public_reviews.dart'
    show HongguoPublicReviews, HongguoPublicReviewsClient;
import 'package:pure_live/modules/hongguo/official/hongguo_related.dart' show HongguoRelatedClient, HongguoRelatedWork;

/// The comment client over the shared transport.
final hongguoCommentClientProvider = Provider<HongguoCommentClient>((ref) {
  return HongguoCommentClient(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
});

/// The public review reader over the shared transport.
final hongguoPublicReviewsClientProvider = Provider<HongguoPublicReviewsClient>((ref) {
  return HongguoPublicReviewsClient(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
});

/// The related/reservation client over the shared transport.
final hongguoRelatedClientProvider = Provider<HongguoRelatedClient>((ref) {
  return HongguoRelatedClient(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
});

/// One episode's comment list: its pages, the cursor, the ask's state.
typedef HongguoCommentsState = ({
  List<HongguoComment> items,
  int total,
  String cursor,
  bool hasMore,
  bool loading,
  String? error,
});

const HongguoCommentsState _idleComments = (
  items: [],
  total: 0,
  cursor: '',
  hasMore: false,
  loading: false,
  error: null,
);

/// Owns one episode's comment list; keyed swaps reset it.
final class HongguoCommentsController extends Notifier<HongguoCommentsState> {
  String _key = '';

  @override
  HongguoCommentsState build() => _idleComments;

  /// Opens the series/episode pair; a repeat of the same pair keeps its
  /// list, including the answer that failed — the panel's own retry is the
  /// way out, so a rebuild never re-asks by itself.
  Future<void> open(String seriesId, String episodeVid) async {
    final key = '$seriesId/$episodeVid';
    if (_key == key) return;
    _key = key;
    state = _idleComments;
    await _load(seriesId, episodeVid);
  }

  /// Runs the held pair's read again (the panel's retry).
  Future<void> retry() async {
    final parts = _key.split('/');
    if (parts.length != 2) return;
    await _load(parts[0], parts[1]);
  }

  /// The next page of the held list.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final parts = _key.split('/');
    if (parts.length != 2) return;
    await _load(parts[0], parts[1]);
  }

  Future<void> _load(String seriesId, String episodeVid) async {
    state = (
      items: state.items,
      total: state.total,
      cursor: state.cursor,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final page = await ref.read(hongguoCommentClientProvider).comments(seriesId, episodeVid, state.cursor);
      state = (
        items: [...state.items, ...page.items],
        total: page.total,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        loading: false,
        error: null,
      );
    } on Object catch (error) {
      state = (
        items: state.items,
        total: state.total,
        cursor: state.cursor,
        hasMore: false,
        loading: false,
        error: hongguoFailureText(error),
      );
    }
  }
}

/// One episode's comment list.
final hongguoCommentsProvider = NotifierProvider<HongguoCommentsController, HongguoCommentsState>(
  HongguoCommentsController.new,
);

/// The danmaku windows the player has already fetched, and the window it is
/// fetching: keyed by series/episode, windows chained by `nextMs`.
@immutable
final class HongguoDanmakuState {
  /// Creates the state.
  const HongguoDanmakuState({this.items = const [], this.nextMs = 0, this.loading = false, this.error});

  /// Every fetched item so far: `(timeMs, text)`, time-ordered.
  final List<(int, String)> items;

  /// Where the next window asks.
  final int nextMs;

  /// Whether a window is in flight.
  final bool loading;

  /// The last window's failure, when one happened.
  final String? error;

  /// The items between [from] and [to], exclusive/inclusive.
  List<(int, String)> between(int from, int to) => [
    for (final item in items)
      if (item.$1 >= from && item.$1 < to) item,
  ];
}

/// Owns one episode's danmaku chain; a playback position poll feeds it.
final class HongguoDanmakuController extends Notifier<HongguoDanmakuState> {
  String _key = '';
  Timer? _poll;

  @override
  HongguoDanmakuState build() => const HongguoDanmakuState();

  /// Starts the chain for the series/episode pair at [durationMs]; the
  /// poll walks the windows while [positionMs] answers where playback is.
  void start(String seriesId, String episodeVid, int durationMs, int Function() positionMs) {
    stop();
    _key = '$seriesId/$episodeVid';
    if (durationMs <= 0) return;
    unawaited(_fetch(seriesId, episodeVid, durationMs));
    _poll = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_key.isEmpty || state.nextMs <= 0 || state.nextMs >= durationMs) {
        timer.cancel();
        return;
      }
      // Fetch the next window when playback is within a minute of it.
      if (positionMs() >= state.nextMs - 60000) {
        unawaited(_fetch(seriesId, episodeVid, durationMs));
      }
    });
  }

  /// Stops the chain and drops the held items.
  void stop() {
    _poll?.cancel();
    _poll = null;
    _key = '';
    state = const HongguoDanmakuState();
  }

  Future<void> _fetch(String seriesId, String episodeVid, int durationMs) async {
    if (state.loading) return;
    final start = state.nextMs;
    state = HongguoDanmakuState(items: state.items, nextMs: start, loading: true);
    try {
      final window = await ref.read(hongguoCommentClientProvider).danmaku(seriesId, episodeVid, start, durationMs);
      final merged = [...state.items, ...window.items]..sort((a, b) => a.$1.compareTo(b.$1));
      state = HongguoDanmakuState(items: merged, nextMs: window.nextMs);
    } on Object catch (error) {
      state = HongguoDanmakuState(items: state.items, nextMs: start, error: hongguoFailureText(error));
    }
  }
}

/// One episode's danmaku chain.
final hongguoDanmakuProvider = NotifierProvider<HongguoDanmakuController, HongguoDanmakuState>(
  HongguoDanmakuController.new,
);

/// One series/episode pair's public reviews and rating.
typedef HongguoPublicReviewsState = ({HongguoPublicReviews? data, bool loading, String? error});

/// Owns the public pages' reviews; a pair change resets it.
final class HongguoPublicReviewsController extends Notifier<HongguoPublicReviewsState> {
  String _key = '';

  @override
  HongguoPublicReviewsState build() => (data: null, loading: false, error: null);

  /// Reads the pair's reviews; the pair already asked — answered or failed —
  /// keeps its answer until the viewer retries.
  Future<void> open(String seriesId, String episodeVid) async {
    final key = '$seriesId/$episodeVid';
    if (_key == key) return;
    await _load(seriesId, episodeVid);
  }

  /// Runs the held pair's read again.
  Future<void> retry() async {
    final parts = _key.split('/');
    if (parts.length != 2) return;
    await _load(parts[0], parts[1]);
  }

  Future<void> _load(String seriesId, String episodeVid) async {
    _key = '$seriesId/$episodeVid';
    state = (data: state.data, loading: true, error: null);
    try {
      final data = await ref.read(hongguoPublicReviewsClientProvider).read(seriesId, episodeVid);
      state = (data: data, loading: false, error: null);
    } on Object catch (error) {
      state = (data: state.data, loading: false, error: hongguoFailureText(error));
    }
  }
}

/// One series/episode pair's public reviews.
final hongguoPublicReviewsProvider = NotifierProvider<HongguoPublicReviewsController, HongguoPublicReviewsState>(
  HongguoPublicReviewsController.new,
);

/// One series' related works and the ask's state.
typedef HongguoRelatedState = ({List<HongguoRelatedWork> items, bool loading, String? error});

/// Owns one series' related list; keyed swaps reset it.
final class HongguoRelatedController extends Notifier<HongguoRelatedState> {
  String _seriesId = '';

  @override
  HongguoRelatedState build() => (items: const [], loading: false, error: null);

  /// Loads the series' related works when it is not the one held.
  Future<void> open(String seriesId) {
    if (_seriesId == seriesId && (state.items.isNotEmpty || state.loading || state.error == null)) {
      return Future.value();
    }
    return _load(seriesId);
  }

  /// Runs the held series' ask again.
  Future<void> retry() => _load(_seriesId);

  Future<void> _load(String seriesId) async {
    _seriesId = seriesId;
    state = (items: const [], loading: true, error: null);
    try {
      final items = await ref.read(hongguoRelatedClientProvider).related(seriesId);
      state = (items: items, loading: false, error: null);
    } on Object catch (error) {
      state = (items: const [], loading: false, error: hongguoFailureText(error));
    }
  }
}

/// One series' related works.
final hongguoRelatedProvider = NotifierProvider<HongguoRelatedController, HongguoRelatedState>(
  HongguoRelatedController.new,
);

/// Books [work] on the signed-in account; the reservations shelf re-reads.
Future<void> hongguoReserveWork(Ref ref, HongguoRelatedWork work) async {
  final credentials = ref.read(hongguoAccountProvider).credentials;
  if (credentials == null) return;
  await ref.read(hongguoRelatedClientProvider).reserve(credentials, work);
  await ref.read(hongguoReservationsProvider.notifier).refresh();
}
