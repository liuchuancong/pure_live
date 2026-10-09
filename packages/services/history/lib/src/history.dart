// Module: lib/src/history.dart
// Purpose: The cross-domain watch history: one record per ContentRef, throttled progress and series views.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/history.md - "跨域统一观看历史,键 = ContentRef;禁止平台前缀类型(BilibiliHistory 等)",
// the record points (start / exit / throttled position), parentId aggregation for series, a mixed timeline
// with a domain filter, and ContinueWatching for what has progress but is not finished.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The four domains the history page groups by. Derived from [ContentKind] rather than stored, because a
/// record whose kind and domain disagreed would be a second truth about the same content.
enum HistoryDomain { live, vod, music, iptv, other }

/// Which domain a content kind belongs to in the unified timeline.
///
/// `liveChannel`/`liveRoom`/`epgProgram` are live; `stream` and `playlist` are ambiguous by kind alone and
/// land in [HistoryDomain.other] rather than being guessed at, because a wrong domain puts the record under
/// the wrong tab and the user reads that as lost history.
HistoryDomain domainOf(ContentKind kind) => switch (kind) {
  ContentKind.liveChannel || ContentKind.liveRoom || ContentKind.epgProgram => HistoryDomain.live,
  ContentKind.vod || ContentKind.movie || ContentKind.series || ContentKind.episode => HistoryDomain.vod,
  ContentKind.music || ContentKind.album || ContentKind.artist => HistoryDomain.music,
  ContentKind.localMedia => HistoryDomain.other,
  ContentKind.stream || ContentKind.playlist => HistoryDomain.other,
};

/// One watched thing, with where the user got to.
final class HistoryEntry {
  const HistoryEntry({
    required this.ref,
    required this.updatedAt,
    this.position = Duration.zero,
    this.duration,
    this.parentId,
    this.snapshot,
  });

  factory HistoryEntry.fromJson(Map<String, Object?> json) => HistoryEntry(
    ref: ContentRef.fromJson(_asMap(json['ref'])),
    updatedAt: _requireUtc(json['updatedAt'], 'history_entry.updatedAt'),
    position: _requireDuration(json['positionMs'], 'history_entry.positionMs'),
    duration: json['durationMs'] == null ? null : _requireDuration(json['durationMs'], 'history_entry.durationMs'),
    parentId: json['parentId'] is String ? json['parentId'] as String : null,
    snapshot: json['snapshot'] == null ? null : ContentSummary.fromJson(_asMap(json['snapshot'])),
  );

  final ContentRef ref;

  /// The last thing that happened to this record. The timeline orders by it and nothing else.
  final DateTime updatedAt;

  /// Where the user got to.
  final Duration position;

  /// What the source said the total length was. Null means it never said, which is not the same as zero:
  /// an unknown length must not be read as "finished at once".
  final Duration? duration;

  /// The containing item (the series an episode belongs to), which is what makes 追更 possible.
  final String? parentId;

  /// Title/cover kept with the record. history.md does not ask for this; favorites.md and playlist.md do, and
  /// a timeline row that renders as a blank tile is the same dead-source problem one page further over.
  final ContentSummary? snapshot;

  /// Finished means the position reached the known length, or the caller said the item ended. A missing
  /// length can never be finished: "unknown duration" is not "zero length".
  bool get isCompleted => duration != null && position >= duration!;

  double? get progress {
    final total = duration;
    if (total == null || total <= Duration.zero) {
      return null;
    }
    final ratio = position.inMilliseconds / total.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  HistoryEntry moved(DateTime now, {Duration? at, Duration? of, ContentSummary? withSnapshot}) => HistoryEntry(
    ref: ref,
    updatedAt: now,
    position: at ?? position,
    duration: of ?? duration,
    parentId: parentId,
    snapshot: withSnapshot ?? snapshot,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'positionMs': position.inMilliseconds,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (parentId != null) 'parentId': parentId,
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
  };

  HistoryDomain get domain => domainOf(ref.kind);

  /// The row's key: which content this is. `ContentRef` equality also compares `parentId`, and a caller that
  /// reports progress without restating the parent must not get a second row for the same thing - so the
  /// record's identity is the content, while [parentId] stays a column that the series view reads.
  String get identityKey => '${ref.sourceId}/${ref.contentId}/${ref.kind.name}';

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.ref == ref &&
      other.updatedAt == updatedAt &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(ref, updatedAt, position, duration);

  @override
  String toString() =>
      'HistoryEntry(${ref.sourceId}/${ref.contentId} @${position.inSeconds}s of '
      '${duration?.inSeconds}s $updatedAt)';
}

/// One series' aggregate: the doc's "看到某剧第 N 集".
final class SeriesProgress {
  const SeriesProgress({required this.parentId, required this.latest, required this.recorded, required this.completed});

  final String parentId;

  /// The most recently touched episode in the series.
  final HistoryEntry latest;

  /// How many distinct children this record set covers.
  final int recorded;

  /// How many of them are finished; `completed == recorded` is what a UI calls "看完".
  final int completed;

  bool get isFullyWatched => completed >= recorded && recorded > 0;

  @override
  String toString() => 'SeriesProgress($parentId $completed/$recorded, latest ${latest.ref.contentId})';
}

/// Where history lives. Fine-grained like the favourites port, so a later Drift binding (the store
/// docs/services/history.md names) can turn these into statements instead of a rewrite.
abstract interface class HistoryRepository {
  Future<List<HistoryEntry>> entries();

  Future<void> upsert(HistoryEntry entry);

  Future<void> remove(ContentRef ref);

  Future<int> removeWhere(bool Function(HistoryEntry) test);

  Future<void> clear();
}

/// Why a history call was refused.
enum HistoryFailure { notFound }

final class HistoryException implements Exception {
  const HistoryException(this.kind, this.detail);

  final HistoryFailure kind;
  final String detail;

  @override
  String toString() => 'HistoryException(${kind.name}: $detail)';
}

/// The unified watch history: record points, timeline, series aggregation and ContinueWatching.
///
/// Throttling is a policy the host supplies ([minWriteInterval], unthrottled by default). The mechanism
/// belongs here because this is the layer that knows a row is a *progress* update; the number belongs to
/// whoever can see the network and the disk, and history.md gives no number.
final class HistoryService {
  HistoryService({
    required HistoryRepository repository,
    DateTime Function()? clock,
    this.minWriteInterval = Duration.zero,
  }) : _repository = repository,
       _clock = clock ?? _utcNow;

  final HistoryRepository _repository;
  final DateTime Function() _clock;

  /// How soon one record may be written again. [Duration.zero] writes every progress tick through.
  final Duration minWriteInterval;

  /// Rows held back by the throttle. A held row is merged into the next accepted write rather than dropped,
  /// which is why [flush] exists: a coalesced tick survives the exit, not only the next interval boundary.
  final Map<String, HistoryEntry> _pending = <String, HistoryEntry>{};

  /// Records a position for [ref]. An absent [duration] keeps the length already on the record, because a
  /// source that stops reporting mid-session must not turn "30 of 45 min" into "30 of unknown".
  Future<HistoryEntry?> record(
    ContentRef ref,
    Duration position, {
    Duration? duration,
    String? parentId,
    ContentSummary? snapshot,
  }) async {
    final existing = await _find(ref);
    final now = _clock();
    final base = existing ?? HistoryEntry(ref: ref, updatedAt: now, position: position);
    final entry = HistoryEntry(
      ref: ref,
      updatedAt: now,
      position: position,
      duration: duration ?? base.duration,
      parentId: parentId ?? base.parentId,
      snapshot: snapshot ?? base.snapshot,
    );
    return _write(entry, existing: existing, force: false);
  }

  /// The exit record point. [at] defaults to the record's own length, which is what makes `finish` mean
  /// "watched to the end"; an unknown length keeps the position as it was rather than inventing an end.
  Future<HistoryEntry> finish(ContentRef ref, {Duration? at}) async {
    final record = await _find(ref);
    if (record == null) {
      throw HistoryException(HistoryFailure.notFound, '${ref.sourceId}/${ref.contentId} has no history record');
    }
    final total = at ?? record.duration;
    final ended = HistoryEntry(
      ref: record.ref,
      updatedAt: _clock(),
      position: total ?? record.position,
      duration: total ?? record.duration,
      parentId: record.parentId,
      snapshot: record.snapshot,
    );
    final written = await _write(ended, existing: record, force: true);
    return written ?? ended;
  }

  /// Writes whatever the throttle held back. The player calls this on exit.
  Future<void> flush() async {
    if (_pending.isEmpty) {
      return;
    }
    final queued = List<HistoryEntry>.of(_pending.values);
    _pending.clear();
    for (final entry in queued) {
      await _repository.upsert(entry);
    }
  }

  /// The mixed timeline, newest first, narrowed by domain, source or a substring of the stored title.
  Future<List<HistoryEntry>> timeline({HistoryDomain? domain, SourceId? sourceId, String? search}) async {
    final needle = search?.trim().toLowerCase();
    final entries = (await _repository.entries()).where((entry) {
      if (domain != null && entry.domain != domain) {
        return false;
      }
      if (sourceId != null && entry.ref.sourceId != sourceId) {
        return false;
      }
      if (needle != null && needle.isNotEmpty) {
        // Local substring matching on the stored title: asking the sources to search their own catalogues is
        // services/search's job, and the history page has to filter what it already holds.
        return (entry.snapshot?.title ?? '').toLowerCase().contains(needle);
      }
      return true;
    }).toList();
    entries.sort((a, b) => -a.updatedAt.compareTo(b.updatedAt));
    return entries;
  }

  /// What has progress but is not finished: "继续观看".
  Future<List<HistoryEntry>> continueWatching({int? limit}) async {
    final open = (await _repository.entries()).where((entry) => !entry.isCompleted).toList()
      ..sort((a, b) => -a.updatedAt.compareTo(b.updatedAt));
    if (limit != null && open.length > limit) {
      return open.sublist(0, limit);
    }
    return open;
  }

  /// One series' aggregate - the doc's "看到某剧第 N 集", built from the children's [HistoryEntry.parentId].
  Future<SeriesProgress?> series(String parentId) async {
    final children = (await _repository.entries()).where((entry) => entry.parentId == parentId).toList()
      ..sort((a, b) => -a.updatedAt.compareTo(b.updatedAt));
    if (children.isEmpty) {
      return null;
    }
    return _aggregate(parentId, children);
  }

  /// The aggregate for every parent that has records. The timeline shows one row per series, so this is where
  /// the episode records collapse into that row.
  Future<Map<String, SeriesProgress>> seriesViews() async {
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in await _repository.entries()) {
      final parent = entry.parentId;
      if (parent != null) {
        grouped.putIfAbsent(parent, () => <HistoryEntry>[]).add(entry);
      }
    }
    return <String, SeriesProgress>{for (final group in grouped.entries) group.key: _aggregate(group.key, group.value)};
  }

  Future<void> remove(ContentRef ref) async {
    final entries = await _repository.entries();
    if (entries.every((entry) => entry.ref != ref)) {
      throw HistoryException(HistoryFailure.notFound, '${ref.sourceId}/${ref.contentId} has no history record');
    }
    _pending.remove(_keyOf(ref));
    await _repository.remove(ref);
  }

  /// Dropping a series drops its episode records. The parent has to be named: clearing the whole page because
  /// one episode was deleted would be a surprise no doc asks for.
  Future<int> removeSeries(String parentId) async {
    _pending.removeWhere((_, entry) => entry.parentId == parentId);
    return _repository.removeWhere((entry) => entry.parentId == parentId);
  }

  /// The 清空 entry point. The confirmation history.md asks for is a UI decision; this does the deletion and
  /// leaves no undo.
  Future<void> clear() async {
    _pending.clear();
    await _repository.clear();
  }

  Future<HistoryEntry?> _find(ContentRef ref) async {
    final key = _keyOf(ref);
    for (final entry in await _repository.entries()) {
      if (entry.identityKey == key) {
        return entry;
      }
    }
    return null;
  }

  static String _keyOf(ContentRef ref) => '${ref.sourceId}/${ref.contentId}/${ref.kind.name}';

  Future<HistoryEntry?> _write(HistoryEntry entry, {HistoryEntry? existing, required bool force}) async {
    final held = _pending[entry.identityKey];
    final merged = held == null || entry.position >= held.position ? entry : held;

    if (!force && !_due(merged, existing)) {
      _pending[merged.identityKey] = merged;
      return null;
    }
    _pending.remove(merged.identityKey);
    await _repository.upsert(merged);
    return merged;
  }

  bool _due(HistoryEntry entry, HistoryEntry? existing) {
    if (minWriteInterval <= Duration.zero) {
      return true;
    }
    if (existing == null) {
      // A first record is always written: dropping it would hide something the user actually watched.
      return true;
    }
    return entry.updatedAt.difference(existing.updatedAt) >= minWriteInterval;
  }

  SeriesProgress _aggregate(String parentId, List<HistoryEntry> children) {
    final sorted = List<HistoryEntry>.of(children)..sort((a, b) => -a.updatedAt.compareTo(b.updatedAt));
    return SeriesProgress(
      parentId: parentId,
      latest: sorted.first,
      recorded: sorted.length,
      completed: sorted.where((entry) => entry.isCompleted).length,
    );
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

Map<String, Object?> _asMap(Object? raw) {
  if (raw is! Map) {
    throw FormatException('expected an object, got ${raw.runtimeType}', raw);
  }
  return Map<String, Object?>.from(raw);
}

DateTime _requireUtc(Object? raw, String field) {
  if (raw is! String) {
    throw FormatException('$field is missing', raw);
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$field is not an ISO-8601 timestamp', raw);
  }
  return parsed.toUtc();
}

Duration _requireDuration(Object? raw, String field) {
  if (raw is! num) {
    throw FormatException('$field is missing', raw);
  }
  return Duration(milliseconds: raw.toInt());
}
