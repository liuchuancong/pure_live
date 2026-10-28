import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_vod/live_vod.dart';

import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// The cinema's six catalogues, in the reference's tab order: Bilibili's own
/// season types.
const List<int> kVodPgcTypes = [1, 4, 2, 3, 5, 7];

/// One catalogue's seasons, the cursor its next page asks with, and its load
/// state.
typedef VodSeasonFeedState = ({
  List<VodSeason> seasons,
  int cursor,
  bool hasMore,
  bool loading,
  bool loaded,
  VodFailure? error,
});

VodSeasonFeedState _seasonFeedInitial() =>
    (seasons: const [], cursor: 0, hasMore: true, loading: false, loaded: false, error: null);

/// The cinema's catalogues, cached per season type.
///
/// A catalogue is cursored rather than paged: each answer names the cursor
/// the next one asks with, and the walk ends when the catalogue says so or
/// when a cursor repeats (a catalogue cannot be walked in place).
final class VodPgcController extends Notifier<Map<int, VodSeasonFeedState>> {
  @override
  Map<int, VodSeasonFeedState> build() => const {};

  /// The catalogue of [type], or the empty page before it is read.
  VodSeasonFeedState of(int type) => state[type] ?? _seasonFeedInitial();

  /// Reads [type]'s first page when it has none and nothing is in flight.
  Future<void> open(int type) async {
    final feed = of(type);
    if (feed.loaded || feed.loading) return;
    await _load(type, 0);
  }

  /// Reads [type]'s next page when the last answer named one.
  Future<void> loadMore(int type) async {
    final feed = of(type);
    if (feed.loading || !feed.hasMore || !feed.loaded) return;
    await _load(type, feed.cursor);
  }

  /// Reads [type]'s first page again (the refresh button).
  Future<void> refresh(int type) => _load(type, 0);

  Future<void> _load(int type, int cursor) async {
    final current = of(type);
    if (current.loading) return;
    state = {...state, type: _with(current, loading: true, clearError: true)};
    try {
      final answer = await ref.read(vodClientProvider).pgcFeed(type: type, cursor: cursor);
      if (!ref.mounted) return;
      final open = state[type];
      if (open == null) return;
      final seasons = cursor == 0 ? answer.seasons : [...open.seasons];
      if (cursor != 0) {
        final seen = {for (final season in seasons) season.seasonId};
        seasons.addAll(answer.seasons.where((season) => seen.add(season.seasonId)));
      }
      state = {
        ...state,
        type: (
          seasons: seasons,
          cursor: answer.cursor,
          hasMore: answer.hasMore && answer.cursor != cursor,
          loading: false,
          loaded: true,
          error: null,
        ),
      };
    } on Object catch (failure) {
      if (!ref.mounted) return;
      final open = state[type];
      if (open == null) return;
      state = {
        ...state,
        type: _with(
          open,
          loading: false,
          hasMore: false,
          loaded: true,
          error: failure is VodFailure ? failure : VodFailure(failure.toString()),
        ),
      };
    }
  }

  VodSeasonFeedState _with(
    VodSeasonFeedState from, {
    List<VodSeason>? seasons,
    int? cursor,
    bool? hasMore,
    bool? loading,
    bool? loaded,
    VodFailure? error,
    bool clearError = false,
  }) => (
    seasons: seasons ?? from.seasons,
    cursor: cursor ?? from.cursor,
    hasMore: hasMore ?? from.hasMore,
    loading: loading ?? from.loading,
    loaded: loaded ?? from.loaded,
    error: clearError ? null : (error ?? from.error),
  );
}

/// The cinema's catalogues.
final vodPgcProvider = NotifierProvider<VodPgcController, Map<int, VodSeasonFeedState>>(VodPgcController.new);

/// One season's page: blurb, episodes and whether the viewer follows it.
final FutureProviderFamily<VodSeasonDetail, int> vodSeasonDetailProvider = FutureProvider.family<VodSeasonDetail, int>((
  ref,
  seasonId,
) {
  return ref.watch(vodClientProvider).seasonDetail(seasonId: seasonId);
});
