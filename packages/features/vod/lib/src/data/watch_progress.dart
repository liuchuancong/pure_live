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
///
/// Each reference is one typed preference row of `pure_live_storage`'s mechanism: envelope, namespace, codec
/// gate and bounded rejection log come from there, and the codec name is what stops a row written by a
/// different shape being read as this one. What stays here is the progress's own rule set - the version check
/// and the two field refusals, which are about watch positions rather than about storage.
final class StoredWatchProgress implements WatchProgressRepository {
  StoredWatchProgress({required KeyValueStore store, Clock? clock, String namespace = 'progress', this.onReadFailure})
    : namespace = requireNonBlank(namespace, name: 'namespace').toLowerCase(),
      _clock = clock ?? systemClock {
    _preferences = PreferencesStore(store: store, namespace: '${this.namespace}.');
  }

  static final PreferenceCodec<WatchProgress> _codec = PreferenceCodec.of<WatchProgress>(
    'watchProgress',
    _decodeDocument,
    (WatchProgress value) => value.toJson(),
  );

  /// The mechanism requires a default for every key; this repository only ever reads with `readIfStored`, so
  /// the value below is a placeholder that is never handed to a caller. Nullability lives in the repository's
  /// own contract ("no row, or a row this build cannot use"), not in the storage layer's.
  static final WatchProgress _noRow = WatchProgress(position: Duration.zero, updatedAt: DateTime.utc(1970));

  late final PreferencesStore _preferences;
  final Clock _clock;

  /// Lets two apps keep separate progress in one store.
  final String namespace;

  final void Function(WatchProgressReadFailure failure)? onReadFailure;

  @override
  Future<WatchProgress?> read(ContentRef ref) async {
    final rejectionsBefore = _preferences.rejections.length;
    final stored = await _preferences.readIfStored(_keyFor(ref));
    if (stored != null) {
      return stored;
    }
    if (_preferences.rejections.length > rejectionsBefore) {
      final rejection = _preferences.rejections.last;
      // The reason the codec gave, when it gave one: "a newer build wrote this" and "there is no position in
      // this row" are different news for whoever has to answer a user's report.
      _report(ref, rejection.reason ?? rejection.failure.name);
    }
    return null;
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
    await _preferences.write(_keyFor(ref), WatchProgress(position: position, duration: duration, updatedAt: _clock()));
  }

  @override
  Future<void> remove(ContentRef ref) => _preferences.reset(_keyFor(ref));

  /// Closes the change stream of the store this repository creates. Rows already saved are durable and stay.
  Future<void> dispose() => _preferences.dispose();

  /// One key per content reference, and the name is not a slash-joined pair.
  ///
  /// `identityKey` length-prefixes each part, so sourceId `a` with contentId `b/c` and sourceId `a/b` with
  /// contentId `c` - which several vod sources really do produce - cannot collide onto one row and overwrite
  /// one viewer's position with another's. The name is unchanged from the pre-mechanism file, so rows already
  /// on disk are the rows this build reads.
  static PreferenceKey<WatchProgress> _keyFor(ContentRef ref) => PreferenceKey<WatchProgress>(
    name: identityKey(<Object?>[ref.sourceId, ref.contentId]),
    codec: _codec,
    defaultValue: _noRow,
    upgrade: _readLegacyRow,
  );

  /// The pre-mechanism row: this file wrote its document as a JSON string under the same key.
  static Object? _readLegacyRow(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static WatchProgress? _decodeDocument(Object? raw) {
    final document = jsonMapFrom(raw);
    if (document == null) {
      return null;
    }
    final version = intFrom(document['v']) ?? 0;
    if (version > kWatchProgressEnvelopeVersion) {
      throw PreferenceDecodeReject('stored row version $version is newer than $kWatchProgressEnvelopeVersion');
    }
    final position = intFrom(document['positionMs']);
    if (position == null || position < 0) {
      throw const PreferenceDecodeReject('a progress row carries no usable positionMs');
    }
    final updatedAt = DateTime.tryParse('${document['updatedAt']}')?.toUtc();
    if (updatedAt == null) {
      throw const PreferenceDecodeReject('a progress row carries no parseable updatedAt');
    }
    final rawDuration = intFrom(document['durationMs']);
    return WatchProgress(
      position: Duration(milliseconds: position),
      duration: rawDuration == null || rawDuration <= 0 ? null : Duration(milliseconds: rawDuration),
      updatedAt: updatedAt,
    );
  }

  void _report(ContentRef ref, String reason, {Object? cause}) {
    onReadFailure?.call(
      WatchProgressReadFailure('progress for ${ref.sourceId}/${ref.contentId} was unusable: $reason', cause: cause),
    );
  }
}
