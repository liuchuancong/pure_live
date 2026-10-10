// Module: lib/src/data/watch_progress_repository.dart
// Purpose: Per-ref watch progress over one kv store: the resume position the
// detail surface reads and the player writes.
// Author: liuchuancong
// Created: 2026-10-10

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';

/// One saved position.
final class WatchProgress {
  const WatchProgress({required this.position, required this.updatedAt, this.duration});

  final Duration position;
  final Duration? duration;
  final DateTime updatedAt;

  /// Whether opening this ref should seek instead of starting over. Below the
  /// threshold a restart is what a viewer wants anyway.
  bool get isResumable => position > const Duration(seconds: 30);

  factory WatchProgress.fromJson(Map<String, Object?> json) => WatchProgress(
    position: Duration(milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0),
    duration: json['durationMs'] == null ? null : Duration(milliseconds: (json['durationMs']! as num).toInt()),
    updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'positionMs': position.inMilliseconds,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// The progress store. Keyed by `sourceId/contentId`, namespaced under
/// `progress.` inside whatever kv store the runtime hands over.
final class WatchProgressRepository {
  WatchProgressRepository({required KeyValueStore store}) : _store = store;

  static const String _prefix = 'progress.';
  final KeyValueStore _store;

  Future<WatchProgress?> read(ContentRef ref) async {
    final raw = await _store.read('$_prefix${ref.sourceId}/${ref.contentId}');
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? WatchProgress.fromJson(Map<String, Object?>.from(decoded)) : null;
    } on FormatException {
      // A corrupt row is a missing row: the store heals on the next write.
      return null;
    }
  }

  Future<void> write(ContentRef ref, Duration position, {Duration? duration}) async {
    final progress = WatchProgress(position: position, duration: duration, updatedAt: DateTime.now().toUtc());
    await _store.write('$_prefix${ref.sourceId}/${ref.contentId}', jsonEncode(progress.toJson()));
  }

  Future<void> remove(ContentRef ref) => _store.remove('$_prefix${ref.sourceId}/${ref.contentId}');
}
