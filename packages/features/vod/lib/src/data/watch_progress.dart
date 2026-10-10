// Module: lib/src/data/watch_progress.dart
// Purpose: The resume position per content reference, with the rule for when resuming is actually wanted.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two rules here are not obvious from the field list, and both were wrong before.
//
// The threshold: a saved position is only worth seeking to if it is past the lead-in *and* not already near
// the end. The previous version asked only "position > 30s", so reopening an episode the viewer had finished
// jumped to 99% of it and looked broken - and a source reporting a zero-length stream made every position
// "near the end" or "not", depending on nothing. Both bounds are now explicit and named.
//
// The key: sourceId and contentId are joined with a length prefix instead of a slash. An id containing a
// slash - which several vod sources produce for path-like episode ids - used to make two different episodes
// collide on one row, silently overwriting one viewer's position with another's.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The envelope version this writer produces.
const int kWatchProgressEnvelopeVersion = 1;

/// Where a saved position came from that this build could not use.
final class WatchProgressReadFailure extends DomainFailure {
  const WatchProgressReadFailure(super.reason, {super.cause});
}

/// One saved position, and whether it is worth seeking to.
final class WatchProgress with ValueEquality {
  const WatchProgress({
    required this.position,
    required this.updatedAt,
    this.duration,
    this.resumeLead = const Duration(seconds: 30),
    this.tailThreshold = const Duration(seconds: 30),
  });

  /// The saved moment.
  final Duration position;

  /// The stream length as known when it was saved; null when the source never said.
  final Duration? duration;

  /// UTC, read through the injected clock.
  final DateTime updatedAt;

  /// Positions shorter than this are restarted: the lead-in of an episode is not a place to resume from.
  final Duration resumeLead;

  /// A position this close to the end is restarted rather than resumed, because the viewer has seen it.
  final Duration tailThreshold;

  /// True when opening this reference should seek to [position] instead of starting over.
  ///
  /// A negative position is never resumable and an unknown length falls back to the lead-in rule alone -
  /// not assuming a length, which would either resume at the end of a live-looking stream or refuse to
  /// resume a real one.
  bool get isResumable {
    if (position.isNegative || position < resumeLead) {
      return false;
    }
    final total = duration;
    if (total == null || total <= Duration.zero) {
      return true;
    }
    return position < total - tailThreshold;
  }

  /// The saved moment as a fraction of the known length, or null when there is no length to divide by.
  double? get progress => duration == null || duration! <= Duration.zero
      ? null
      : clampDouble(position.inMilliseconds / duration!.inMilliseconds, lower: 0, upper: 1);

  @override
  List<Object?> get equalityFields => <Object?>[position, duration, updatedAt];

  Map<String, Object?> toJson() => <String, Object?>{
    'v': kWatchProgressEnvelopeVersion,
    'positionMs': position.inMilliseconds,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Reads a saved row, or null when it is unusable.
  ///
  /// [onReadFailure] is notified only for something that looked like damage. A row written by this build
  /// cannot fail to parse; an older row without the version field is read as version 0, which is a migration.
  static WatchProgress? fromJson(
    Map<String, Object?> json, {
    void Function(WatchProgressReadFailure failure)? onReadFailure,
  }) {
    final position = intFrom(json['positionMs']);
    if (position == null || position < 0) {
      onReadFailure?.call(WatchProgressReadFailure('a progress row carries no usable positionMs'));
      return null;
    }
    final rawDuration = intFrom(json['durationMs']);
    final updatedAt = DateTime.tryParse('${json['updatedAt']}')?.toUtc();
    if (updatedAt == null) {
      onReadFailure?.call(WatchProgressReadFailure('a progress row carries no parseable updatedAt'));
      return null;
    }
    return WatchProgress(
      position: Duration(milliseconds: position),
      duration: rawDuration == null || rawDuration <= 0 ? null : Duration(milliseconds: rawDuration),
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'WatchProgress(${position.inSeconds}s of ${duration == null ? '?' : '${duration!.inSeconds}s'})';
}

/// Reads and writes the resume position of one content reference.
abstract interface class WatchProgressRepository {
  /// The saved position for [ref], or null when there is none or the row could not be used.
  Future<WatchProgress?> read(ContentRef ref);

  /// Saves a position for [ref]. The saved row is what [read] returns afterwards.
  Future<void> save(ContentRef ref, Duration position, {Duration? duration});

  /// Drops the saved position, e.g. when playback reaches the end.
  Future<void> remove(ContentRef ref);
}

/// The kv-backed [WatchProgressRepository].
final class StoredWatchProgress implements WatchProgressRepository {
  StoredWatchProgress({required KeyValueStore store, Clock? clock, String namespace = 'progress', this.onReadFailure})
    : _store = store,
      _clock = clock ?? systemClock,
      namespace = requireNonBlank(namespace, name: 'namespace').toLowerCase();

  final KeyValueStore _store;
  final Clock _clock;

  /// Lets two apps keep separate progress in one store.
  final String namespace;

  final void Function(WatchProgressReadFailure failure)? onReadFailure;

  @override
  Future<WatchProgress?> read(ContentRef ref) async {
    final raw = await _store.read(_key(ref));
    if (raw == null) {
      return null;
    }
    if (raw is! String || raw.isEmpty) {
      _report('stored value is not text', ref, cause: raw.runtimeType);
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      _report('stored row is not json', ref, cause: error);
      return null;
    }
    final fields = jsonMapFrom(decoded);
    if (fields == null) {
      _report('stored row is not an object', ref);
      return null;
    }
    final version = intFrom(fields['v']) ?? 0;
    if (version > kWatchProgressEnvelopeVersion) {
      _report('stored row version $version is newer than $kWatchProgressEnvelopeVersion', ref);
      return null;
    }
    return WatchProgress.fromJson(fields, onReadFailure: onReadFailure);
  }

  @override
  Future<void> save(ContentRef ref, Duration position, {Duration? duration}) async {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'a watch position cannot be negative');
    }
    if (duration != null && duration <= Duration.zero) {
      // A zero or negative length is not a length; storing it would make every position look like it ran
      // past the end and stop the episode from ever resuming.
      throw ArgumentError.value(duration, 'duration', 'must be longer than zero when given');
    }
    final progress = WatchProgress(position: position, duration: duration, updatedAt: _clock());
    await _store.write(_key(ref), jsonEncode(progress.toJson()));
  }

  @override
  Future<void> remove(ContentRef ref) => _store.remove(_key(ref));

  String _key(ContentRef ref) => '$namespace.${identityKey(<Object?>[ref.sourceId, ref.contentId])}';

  void _report(String reason, ContentRef ref, {Object? cause}) {
    onReadFailure?.call(
      WatchProgressReadFailure('progress for ${ref.sourceId}/${ref.contentId} was unusable: $reason', cause: cause),
    );
  }
}
