import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoFailureText;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';

/// One watch-history row: the series snapshot it needs to render on its
/// own, plus where playback stood.
@immutable
final class HongguoWatchProgress {
  /// Creates the row.
  const HongguoWatchProgress({
    required this.seriesId,
    required this.title,
    required this.cover,
    required this.episodeIndex,
    required this.episodeVid,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.updatedAt,
    this.episodeCount = 0,
  });

  /// Reads the row from its stored form.
  factory HongguoWatchProgress.fromJson(Map<String, Object?> json) => HongguoWatchProgress(
    seriesId: json['seriesId'] is String ? json['seriesId']! as String : '',
    title: json['title'] is String ? json['title']! as String : '',
    cover: json['cover'] is String ? json['cover']! as String : '',
    episodeIndex: (json['episodeIndex'] as num?)?.toInt() ?? 1,
    episodeVid: json['episodeVid'] is String ? json['episodeVid']! as String : '',
    positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    completed: json['completed'] == true,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    episodeCount: (json['episodeCount'] as num?)?.toInt() ?? 0,
  );

  /// The series the progress belongs to.
  final String seriesId;

  /// The series' name when it was watched.
  final String title;

  /// The series' cover when it was watched.
  final String cover;

  /// The 1-based episode last watched.
  final int episodeIndex;

  /// That episode's vid.
  final String episodeVid;

  /// Where playback stood, in milliseconds.
  final int positionMs;

  /// The episode's length, in milliseconds.
  final int durationMs;

  /// Whether the series was finished.
  final bool completed;

  /// When the row was last touched.
  final int updatedAt;

  /// The series' episode count when it was watched.
  final int episodeCount;

  /// Serializes for storage.
  Map<String, Object?> toJson() => {
    'seriesId': seriesId,
    'title': title,
    'cover': cover,
    'episodeIndex': episodeIndex,
    'episodeVid': episodeVid,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'completed': completed,
    'updatedAt': updatedAt,
    'episodeCount': episodeCount,
  };

  /// The row's share watched, 0..1, for a progress bar.
  double get fraction => durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);
}

/// What the last update check found for one favorite: how many episodes the
/// series has now, how many the viewer had when the shelf line was drawn,
/// and when it was read.
@immutable
final class HongguoFavoriteUpdate {
  /// Creates the record.
  const HongguoFavoriteUpdate({required this.total, required this.seen, required this.checkedAt});

  /// Reads the stored record.
  factory HongguoFavoriteUpdate.fromJson(Map<String, Object?> json) => HongguoFavoriteUpdate(
    total: (json['total'] as num?)?.toInt() ?? 0,
    seen: (json['seen'] as num?)?.toInt() ?? 0,
    checkedAt: (json['checkedAt'] as num?)?.toInt() ?? 0,
  );

  /// The series' episode count as the platform answers it now.
  final int total;

  /// The count the shelf held when the series was favorited.
  final int seen;

  /// When the check ran.
  final int checkedAt;

  /// How many episodes the series gained since the shelf line was drawn.
  int get added => (total - seen).clamp(0, total);

  /// Serializes for storage.
  Map<String, Object?> toJson() => {'total': total, 'seen': seen, 'checkedAt': checkedAt};
}

/// The viewer's own shelves: the local favorites and the watch history,
/// kept on this machine only — the reference's rule.
@immutable
final class HongguoLibraryState {
  /// Creates the state.
  const HongguoLibraryState({
    this.favorites = const [],
    this.history = const [],
    this.updates = const {},
    this.checking = false,
    this.checksDone = 0,
    this.checksTotal = 0,
    this.checkFailures = 0,
    this.checkError,
  });

  /// The favorited series, newest first.
  final List<HongguoSeries> favorites;

  /// The watch history, most recent first.
  final List<HongguoWatchProgress> history;

  /// What the last update check found, by series.
  final Map<String, HongguoFavoriteUpdate> updates;

  /// Whether an update check is running.
  final bool checking;

  /// How many favorites the running check has read, and how many it holds.
  final int checksDone;
  final int checksTotal;

  /// How many of those reads failed.
  final int checkFailures;

  /// Why the last check stopped early, when it did.
  final String? checkError;

  /// Whether [seriesId] is favorited.
  bool isFavorite(String seriesId) => favorites.any((series) => series.seriesId == seriesId);

  /// The series' progress row, when one exists.
  HongguoWatchProgress? progressOf(String seriesId) {
    for (final row in history) {
      if (row.seriesId == seriesId) return row;
    }
    return null;
  }

  /// The state with the named parts replaced.
  HongguoLibraryState copyWith({
    List<HongguoSeries>? favorites,
    List<HongguoWatchProgress>? history,
    Map<String, HongguoFavoriteUpdate>? updates,
    bool? checking,
    int? checksDone,
    int? checksTotal,
    int? checkFailures,
    String? checkError,
  }) => HongguoLibraryState(
    favorites: favorites ?? this.favorites,
    history: history ?? this.history,
    updates: updates ?? this.updates,
    checking: checking ?? this.checking,
    checksDone: checksDone ?? this.checksDone,
    checksTotal: checksTotal ?? this.checksTotal,
    checkFailures: checkFailures ?? this.checkFailures,
    checkError: checkError ?? this.checkError,
  );
}

const String _kFavoritesKey = 'hongguo.library.favorites';
const String _kHistoryKey = 'hongguo.library.history';
const String _kUpdatesKey = 'hongguo.library.favoriteUpdates';

/// Owns the local shelves, writing through to storage on every change.
final class HongguoLibraryController extends Notifier<HongguoLibraryState> {
  /// How often one favorite may be re-read, and how many failures in a row
  /// stop the walk — the reference's numbers.
  static const Duration _checkTtl = Duration(hours: 1);
  static const int _maxConsecutiveFailures = 3;

  @override
  HongguoLibraryState build() =>
      HongguoLibraryState(favorites: _readFavorites(), history: _readHistory(), updates: _readUpdates());

  static List<HongguoSeries> _readFavorites() {
    try {
      final raw = StoragePrefs.getString(_kFavoritesKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const [];
      return [
        for (final row in decoded.take(500))
          if (row is Map<String, Object?>)
            HongguoSeries(
              seriesId: row['seriesId'] is String ? row['seriesId']! as String : '',
              title: row['title'] is String ? row['title']! as String : '',
              cover: row['cover'] is String ? row['cover']! as String : '',
              intro: row['intro'] is String ? row['intro']! as String : '',
              episodeCount: (row['episodeCount'] as num?)?.toInt() ?? 0,
            ),
      ].where((series) => series.seriesId.isNotEmpty).toList();
    } on Object {
      return const [];
    }
  }

  static List<HongguoWatchProgress> _readHistory() {
    try {
      final raw = StoragePrefs.getString(_kHistoryKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const [];
      final rows = [
        for (final row in decoded.take(200))
          if (row is Map<String, Object?>) HongguoWatchProgress.fromJson(row),
      ].where((row) => row.seriesId.isNotEmpty).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rows;
    } on Object {
      return const [];
    }
  }

  static Map<String, HongguoFavoriteUpdate> _readUpdates() {
    try {
      final raw = StoragePrefs.getString(_kUpdatesKey);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const {};
      return {
        for (final entry in decoded.entries.take(500))
          if (entry.value is Map<String, Object?>)
            entry.key: HongguoFavoriteUpdate.fromJson(entry.value! as Map<String, Object?>),
      };
    } on Object {
      return const {};
    }
  }

  void _persist() {
    try {
      unawaited(
        StoragePrefs.setString(
          _kFavoritesKey,
          jsonEncode([
            for (final series in state.favorites)
              {
                'seriesId': series.seriesId,
                'title': series.title,
                'cover': series.cover,
                'intro': series.intro,
                'episodeCount': series.episodeCount,
              },
          ]),
        ),
      );
      unawaited(StoragePrefs.setString(_kHistoryKey, jsonEncode([for (final row in state.history) row.toJson()])));
      unawaited(
        StoragePrefs.setString(
          _kUpdatesKey,
          jsonEncode({for (final entry in state.updates.entries) entry.key: entry.value.toJson()}),
        ),
      );
    } on Object {
      // A closed store loses the shelves; the next change retries.
    }
  }

  /// Adds or removes [series] on the local shelf; answers whether it ended
  /// favorited.
  bool toggleFavorite(HongguoSeries series) {
    final added = !state.isFavorite(series.seriesId);
    final favorites = added
        ? [series, ...state.favorites].take(500).toList()
        : [
            for (final kept in state.favorites)
              if (kept.seriesId != series.seriesId) kept,
          ];
    // A series that leaves the shelf leaves its update row behind — the
    // reference drops it with the favorite.
    final updates = added
        ? state.updates
        : {
            for (final entry in state.updates.entries)
              if (entry.key != series.seriesId) entry.key: entry.value,
          };
    state = state.copyWith(favorites: favorites, updates: updates);
    _persist();
    return added;
  }

  /// Acknowledges what a check found when the viewer opens the series: the
  /// shelf's `新增 N 集` line stops at the count read.
  void acknowledgeUpdates(String seriesId) {
    final row = state.updates[seriesId];
    if (row == null || row.added == 0) return;
    final updates = Map<String, HongguoFavoriteUpdate>.of(state.updates);
    updates[seriesId] = HongguoFavoriteUpdate(total: row.total, seen: row.total, checkedAt: row.checkedAt);
    state = state.copyWith(updates: updates);
    _persist();
  }

  /// Records [progress], moving the series to the history's head. An
  /// identical paused checkpoint does not rewrite the row.
  void saveProgress(HongguoWatchProgress progress) {
    final previous = state.progressOf(progress.seriesId);
    if (previous != null &&
        previous.episodeVid == progress.episodeVid &&
        previous.positionMs == progress.positionMs &&
        previous.completed == progress.completed) {
      return;
    }
    final history = ([progress, ...state.history.where((row) => row.seriesId != progress.seriesId)].take(200).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    state = state.copyWith(history: history);
    _persist();
  }

  /// Forgets one series' progress; its favorite, if any, stays.
  void removeHistory(String seriesId) {
    state = state.copyWith(
      history: [
        for (final row in state.history)
          if (row.seriesId != seriesId) row,
      ],
    );
    _persist();
  }

  /// Clears the whole history.
  void clearHistory() {
    state = state.copyWith(history: const []);
    _persist();
  }

  /// Reads the favorited series' episode counts, one at a time, so the shelf
  /// can say what a series grew by. Only the ones not read in the last hour
  /// are asked; [force] asks them all. Three failures in a row stop the walk
  /// rather than keep the viewer waiting on a network that is not answering.
  Future<void> checkUpdates({bool force = false}) async {
    if (state.checking) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = [
      for (final series in state.favorites)
        if (force || now - (state.updates[series.seriesId]?.checkedAt ?? 0) > _checkTtl.inMilliseconds) series,
    ];
    if (due.isEmpty) return;
    state = HongguoLibraryState(
      favorites: state.favorites,
      history: state.history,
      updates: state.updates,
      checking: true,
      checksTotal: due.length,
    );
    final updates = Map<String, HongguoFavoriteUpdate>.of(state.updates);
    var done = 0;
    var failures = 0;
    var consecutive = 0;
    String? error;
    final client = ref.read(hongguoClientProvider);
    for (final series in due) {
      try {
        final total = (await client.detail(series.seriesId)).meta.episodeCount;
        if (total > 0) {
          updates[series.seriesId] = HongguoFavoriteUpdate(total: total, seen: series.episodeCount, checkedAt: now);
        }
        consecutive = 0;
      } on Object catch (failure) {
        failures++;
        consecutive++;
        error = hongguoFailureText(failure);
      }
      done++;
      state = state.copyWith(updates: updates, checksDone: done, checkFailures: failures);
      if (error != null) state = state.copyWith(checkError: error);
      if (consecutive >= _maxConsecutiveFailures) break;
    }
    // The walk's own summary replaces its running state; a walk that ended
    // clean must not keep a failure line from a favorite it recovered from.
    state = HongguoLibraryState(
      favorites: state.favorites,
      history: state.history,
      updates: updates,
      checksDone: done,
      checksTotal: due.length,
      checkFailures: failures,
      checkError: failures == 0 ? null : state.checkError,
    );
    _persist();
  }
}

/// The viewer's local shelves.
final hongguoLibraryProvider = NotifierProvider<HongguoLibraryController, HongguoLibraryState>(
  HongguoLibraryController.new,
);
