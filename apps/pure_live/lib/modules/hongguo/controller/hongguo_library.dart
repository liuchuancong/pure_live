import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

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

/// The viewer's own shelves: the local favorites and the watch history,
/// kept on this machine only — the reference's rule.
@immutable
final class HongguoLibraryState {
  /// Creates the state.
  const HongguoLibraryState({this.favorites = const [], this.history = const []});

  /// The favorited series, newest first.
  final List<HongguoSeries> favorites;

  /// The watch history, most recent first.
  final List<HongguoWatchProgress> history;

  /// Whether [seriesId] is favorited.
  bool isFavorite(String seriesId) => favorites.any((series) => series.seriesId == seriesId);

  /// The series' progress row, when one exists.
  HongguoWatchProgress? progressOf(String seriesId) {
    for (final row in history) {
      if (row.seriesId == seriesId) return row;
    }
    return null;
  }
}

const String _kFavoritesKey = 'hongguo.library.favorites';
const String _kHistoryKey = 'hongguo.library.history';

/// Owns the local shelves, writing through to storage on every change.
final class HongguoLibraryController extends Notifier<HongguoLibraryState> {
  @override
  HongguoLibraryState build() => HongguoLibraryState(favorites: _readFavorites(), history: _readHistory());

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
      ].where((row) => row.seriesId.isNotEmpty).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rows;
    } on Object {
      return const [];
    }
  }

  void _persist() {
    try {
      unawaited(StoragePrefs.setString(
        _kFavoritesKey,
        jsonEncode([
          for (final series in state.favorites)
            {'seriesId': series.seriesId, 'title': series.title, 'cover': series.cover, 'intro': series.intro, 'episodeCount': series.episodeCount},
        ]),
      ));
      unawaited(StoragePrefs.setString(
        _kHistoryKey,
        jsonEncode([for (final row in state.history) row.toJson()]),
      ));
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
        : [for (final kept in state.favorites) if (kept.seriesId != series.seriesId) kept];
    state = HongguoLibraryState(favorites: favorites, history: state.history);
    _persist();
    return added;
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
    state = HongguoLibraryState(favorites: state.favorites, history: history);
    _persist();
  }

  /// Forgets one series' progress; its favorite, if any, stays.
  void removeHistory(String seriesId) {
    state = HongguoLibraryState(
      favorites: state.favorites,
      history: [for (final row in state.history) if (row.seriesId != seriesId) row],
    );
    _persist();
  }

  /// Clears the whole history.
  void clearHistory() {
    state = HongguoLibraryState(favorites: state.favorites);
    _persist();
  }
}

/// The viewer's local shelves.
final hongguoLibraryProvider =
    NotifierProvider<HongguoLibraryController, HongguoLibraryState>(HongguoLibraryController.new);
