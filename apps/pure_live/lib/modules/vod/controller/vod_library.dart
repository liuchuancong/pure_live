import 'dart:async' show Completer, StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart' show VodDetail, VodVideo;

/// The preference the video station's collected archives are kept under.
const String kVodFavouritesKey = 'vod.favourites';

/// Where the player writes one archive's playback position; the history page
/// reads every entry under this prefix.
const String kVodProgressPrefix = 'vod.progress.';

/// How many archives' checkpoints the record keeps; the overflow's oldest
/// keys leave the store, so years of watching do not grow the settings
/// document without end.
const int kVodHistoryLimit = 200;

/// An archive as the station keeps it: enough to draw its row and open its
/// page without asking the source again.
@immutable
final class VodSavedVideo {
  /// A saved archive.
  const VodSavedVideo({
    required this.bvid,
    required this.title,
    required this.updatedAt,
    this.coverUrl,
    this.uploader,
    this.durationSeconds,
  });

  /// The record for [detail].
  factory VodSavedVideo.ofDetail(VodDetail detail, {DateTime? at}) => VodSavedVideo(
    bvid: detail.bvid,
    title: detail.title,
    coverUrl: detail.coverUrl,
    uploader: detail.uploader,
    durationSeconds: detail.duration == null ? null : detail.duration!.inMilliseconds / 1000,
    updatedAt: at ?? DateTime.now(),
  );

  /// The record for a feed [video].
  factory VodSavedVideo.ofVideo(VodVideo video, {DateTime? at}) => VodSavedVideo(
    bvid: video.bvid ?? video.id,
    title: video.title,
    coverUrl: video.coverUrl,
    uploader: video.uploader,
    durationSeconds: video.duration == null ? null : video.duration!.inMilliseconds / 1000,
    updatedAt: at ?? DateTime.now(),
  );

  /// The archive's bvid.
  final String bvid;

  /// Its title.
  final String title;

  /// Its cover.
  final String? coverUrl;

  /// Its uploader.
  final String? uploader;

  /// Its length in seconds, when the source gave one.
  final double? durationSeconds;

  /// When it was saved (or last played, for a history entry).
  final DateTime updatedAt;

  /// The shape the station's rows draw.
  VodVideo get video => VodVideo(
    id: bvid,
    bvid: bvid,
    title: title,
    coverUrl: coverUrl,
    uploader: uploader,
    duration: durationSeconds == null ? null : Duration(milliseconds: (durationSeconds! * 1000).round()),
  );

  /// Reads a stored entry; null when it is damaged.
  static VodSavedVideo? fromJson(Object? json) {
    if (json is! Map) return null;
    final bvid = json['bvid'];
    final title = json['title'];
    if (bvid is! String || bvid.isEmpty || title is! String) return null;
    final updatedAt = (json['updatedAt'] as num?)?.toInt();
    return VodSavedVideo(
      bvid: bvid,
      title: title,
      coverUrl: json['coverUrl'] is String ? json['coverUrl'] as String : null,
      uploader: json['uploader'] is String ? json['uploader'] as String : null,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      updatedAt: updatedAt == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  /// The stored shape.
  Map<String, Object?> toJson() => {
    'bvid': bvid,
    'title': title,
    'coverUrl': coverUrl,
    'uploader': uploader,
    'durationSeconds': durationSeconds,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

/// The archives the viewer collected, newest first.
final class VodFavouritesController extends Notifier<List<VodSavedVideo>> {
  VodFavouritesController({Future<void> Function(String key, String value)? write})
    : _write = write ?? StoragePrefs.setString;

  final Future<void> Function(String key, String value) _write;
  Future<void> _pending = Future<void>.value();

  @override
  List<VodSavedVideo> build() {
    try {
      final raw = StoragePrefs.getString(kVodFavouritesKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?VodSavedVideo.fromJson(entry)];
    } on Object {
      return const [];
    }
  }

  /// Whether [bvid] is collected.
  bool contains(String bvid) => state.any((video) => video.bvid == bvid);

  /// Collects [video], or drops it when it is already collected.
  Future<bool> toggle(VodSavedVideo video) => _enqueue(() async {
    final before = state;
    final collected = contains(video.bvid);
    final next = collected
        ? [
            for (final entry in before)
              if (entry.bvid != video.bvid) entry,
          ]
        : [video, ...before];
    state = next;
    try {
      await _persist(next);
      return !collected;
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  });

  /// Drops one archive.
  Future<void> remove(String bvid) => _enqueue(() async {
    final before = state;
    final next = [
      for (final entry in before)
        if (entry.bvid != bvid) entry,
    ];
    state = next;
    try {
      await _persist(next);
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  });

  /// Drops the selected archives in one preference write.
  Future<void> removeMany(Iterable<String> bvids) => _enqueue(() async {
    final removed = bvids.toSet();
    if (removed.isEmpty) return;
    final before = state;
    final next = [
      for (final entry in before)
        if (!removed.contains(entry.bvid)) entry,
    ];
    state = next;
    try {
      await _persist(next);
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        result.complete(await action());
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> _persist(List<VodSavedVideo> videos) =>
      _write(kVodFavouritesKey, jsonEncode([for (final video in videos) video.toJson()]));
}

/// The collected archives.
final vodFavouritesProvider = NotifierProvider<VodFavouritesController, List<VodSavedVideo>>(
  VodFavouritesController.new,
);

/// One archive the player has written a position for.
@immutable
final class VodHistoryEntry {
  /// A history record.
  const VodHistoryEntry({required this.video, required this.positionSeconds, required this.completed});

  /// The archive's metadata as the player last wrote it.
  final VodSavedVideo video;

  /// Where playback stopped.
  final double positionSeconds;

  /// Whether the archive was played to its end.
  final bool completed;

  /// The bvid.
  String get bvid => video.bvid;
}

/// The archive history, newest first.
///
/// The player already stores a position per bvid; this notifier reads those
/// entries out of the preference store and follows the store's change
/// stream, so finishing a video or starting another updates the page without
/// a second copy of the data.
final class VodHistoryController extends Notifier<List<VodHistoryEntry>> {
  StreamSubscription<Set<String>>? _subscription;

  /// The read after a write: playback stores a checkpoint every few
  /// seconds, and each store broadcast would otherwise re-read the whole
  /// snapshot — a burst of writes settles on one read, shortly after the
  /// last.
  Timer? _reload;

  /// The archives removed just now: a writer already in flight — another
  /// window's throttled checkpoint, the mini window's close — would
  /// otherwise put a just-removed record straight back. A removal mutes
  /// only the writers racing it; a minute later watching the archive again
  /// brings the record back, the way it should.
  final Map<String, DateTime> _tombstones = {};
  Future<void> _pending = Future<void>.value();

  @override
  List<VodHistoryEntry> build() {
    _subscription = StoragePrefs.watch().listen((keys) {
      if (!keys.any((key) => key.startsWith(kVodProgressPrefix))) return;
      _reload?.cancel();
      _reload = Timer(const Duration(milliseconds: 800), () => state = _read());
    });
    ref.onDispose(() {
      unawaited(_subscription?.cancel() ?? Future<void>.value());
      _reload?.cancel();
    });
    return _read();
  }

  /// Writes one archive's checkpoint — the video page calls it on a throttle
  /// as playback runs. The entry doubles as the history record the station's
  /// 个人 page reads, so it carries the archive's metadata; finishing marks
  /// the record done rather than clearing it.
  Future<void> save({
    required String bvid,
    required int cid,
    required double seconds,
    required String title,
    required double durationSeconds,
    String? cover,
    String? uploader,
    bool completed = false,
  }) => _enqueue(
    () => _save(
      bvid: bvid,
      cid: cid,
      seconds: seconds,
      title: title,
      durationSeconds: durationSeconds,
      cover: cover,
      uploader: uploader,
      completed: completed,
    ),
  );

  Future<void> _save({
    required String bvid,
    required int cid,
    required double seconds,
    required String title,
    required double durationSeconds,
    String? cover,
    String? uploader,
    bool completed = false,
  }) async {
    // A removal just made mutes this write: the viewer took the record
    // out, and a checkpoint that left before the removal does not put it
    // back.
    final tombstone = _tombstones[bvid];
    if (tombstone != null) {
      if (DateTime.now().difference(tombstone) < const Duration(minutes: 1)) return;
      _tombstones.remove(bvid);
    }
    final key = '$kVodProgressPrefix$bvid';
    try {
      await StoragePrefs.setString(
        key,
        jsonEncode({
          'cid': cid,
          'seconds': completed ? durationSeconds : seconds,
          'title': title,
          'cover': cover,
          'uploader': uploader,
          'durationSeconds': durationSeconds,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          if (completed) 'completed': true,
        }),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
    await _prune(
      written: VodHistoryEntry(
        video: VodSavedVideo(
          bvid: bvid,
          title: title,
          coverUrl: cover,
          uploader: uploader,
          durationSeconds: durationSeconds,
          updatedAt: DateTime.now(),
        ),
        positionSeconds: completed ? durationSeconds : seconds,
        completed: completed,
      ),
    );
  }

  /// Caps the record at [kVodHistoryLimit]: the overflow's oldest
  /// checkpoints leave the store after each write. The in-memory list
  /// plus the entry just written decides — a full-store rescan on every
  /// five-second checkpoint is the expensive kind of tidiness.
  Future<void> _prune({required VodHistoryEntry written}) async {
    final merged = [written, ...state.where((entry) => entry.video.bvid != written.video.bvid)]
      ..sort((a, b) => b.video.updatedAt.compareTo(a.video.updatedAt));
    for (final entry in merged.skip(kVodHistoryLimit)) {
      try {
        await StoragePrefs.remove('$kVodProgressPrefix${entry.video.bvid}');
      } on Object {
        // A preference; a closed store loses it.
      }
    }
  }

  /// The place to resume [bvid] from — which part and how far in. A finished
  /// archive keeps its history entry but is not resumed.
  ({int cid, double seconds})? resumePoint(String bvid) {
    try {
      final raw = StoragePrefs.getString('$kVodProgressPrefix$bvid');
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      if (json['completed'] == true) return null;
      final cid = (json['cid'] as num?)?.toInt();
      final seconds = (json['seconds'] as num?)?.toDouble();
      if (cid == null || seconds == null || seconds < 0) return null;
      return (cid: cid, seconds: seconds);
    } on Object {
      return null;
    }
  }

  /// Reads one part's viewer-set opening and ending points, falling back to
  /// the archive-wide record written before the points became part-scoped.
  VodSkipPoints? skipPoints(String bvid, {int? cid}) {
    try {
      final scoped = cid == null ? null : StoragePrefs.getString('$kVodSkipPrefix$bvid:$cid');
      return VodSkipPoints.parse(scoped ?? StoragePrefs.getString('$kVodSkipPrefix$bvid'));
    } on Object {
      return null;
    }
  }

  /// Writes one part's opening and ending points.
  Future<void> saveSkipPoints(String bvid, {int? cid, double? headSeconds, double? tailSeconds}) async {
    final suffix = cid == null ? '' : ':$cid';
    try {
      await StoragePrefs.setString(
        '$kVodSkipPrefix$bvid$suffix',
        jsonEncode({'head': headSeconds?.round(), 'tail': tailSeconds?.round()}),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Drops one archive's entry.
  Future<void> remove(String bvid) => _enqueue(() => _remove(bvid));

  Future<void> _remove(String bvid) async {
    // The prefix is a constant, the bvid is not: the manifest gate treats
    // this as a computed key and lists it for review instead of demanding a
    // static entry.
    _tombstones[bvid] = DateTime.now();
    final key = '$kVodProgressPrefix$bvid';
    try {
      await StoragePrefs.remove(key);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Drops the selected entries, one removal each — the batch management
  /// own verb.
  Future<void> removeMany(Iterable<String> bvids) async {
    for (final bvid in bvids) {
      await remove(bvid);
    }
  }

  /// Drops every entry, including checkpoints written since the last refresh.
  Future<void> clear() => _enqueue(() async {
    final bvids = {
      for (final entry in state) entry.bvid,
      for (final key in StoragePrefs.snapshot().keys)
        if (key.startsWith(kVodProgressPrefix)) key.substring(kVodProgressPrefix.length),
    };
    final now = DateTime.now();
    for (final bvid in bvids) {
      _tombstones[bvid] = now;
      try {
        await StoragePrefs.remove('$kVodProgressPrefix$bvid');
      } on Object {
        // A preference; a closed store loses it.
      }
    }
    _reload?.cancel();
    state = const [];
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        result.complete(await action());
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static List<VodHistoryEntry> _read() {
    final List<VodHistoryEntry> entries;
    try {
      entries = [
        for (final MapEntry(:key, :value) in StoragePrefs.snapshot().entries)
          if (key.startsWith(kVodProgressPrefix)) ?_parse(key, value),
      ];
    } on Object {
      return const [];
    }
    entries.sort((a, b) => b.video.updatedAt.compareTo(a.video.updatedAt));
    if (entries.length > kVodHistoryLimit) return entries.take(kVodHistoryLimit).toList();
    return entries;
  }

  static VodHistoryEntry? _parse(String key, Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      final bvid = key.substring(kVodProgressPrefix.length);
      final seconds = (json['seconds'] as num?)?.toDouble();
      if (bvid.isEmpty || seconds == null) return null;
      final title = json['title'];
      if (title is! String || title.isEmpty) return null;
      final duration = (json['durationSeconds'] as num?)?.toDouble();
      final updatedAt = (json['updatedAt'] as num?)?.toInt();
      return VodHistoryEntry(
        video: VodSavedVideo(
          bvid: bvid,
          title: title,
          coverUrl: json['cover'] is String ? json['cover'] as String : null,
          uploader: json['uploader'] is String ? json['uploader'] as String : null,
          durationSeconds: duration,
          updatedAt: updatedAt == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        ),
        positionSeconds: seconds,
        completed: json['completed'] == true,
      );
    } on Object {
      return null;
    }
  }
}

/// The archive history.
final vodHistoryProvider = NotifierProvider<VodHistoryController, List<VodHistoryEntry>>(VodHistoryController.new);

/// The preference prefix one series' continue checkpoint lives under — the
/// season page writes one per series, and the manifest gate reviews the
/// prefix as a computed key, the way it reviews the archive history's.
const String kVodSeasonProgressPrefix = 'vod.season.progress.';

/// How many series' checkpoints the store keeps; an older one is dropped
/// when the shelf outgrows it.
const int kVodSeasonProgressLimit = 100;

/// One series' checkpoint: where the season page last opened an episode —
/// the cinema page's continue card reads the newest one that is not done.
@immutable
final class VodSeasonProgress {
  /// A checkpoint.
  const VodSeasonProgress({
    required this.seasonId,
    required this.title,
    required this.episodeIndex,
    required this.updatedAt,
    this.cover,
    this.positionSeconds,
    this.total,
    this.finished = false,
  });

  /// The season the checkpoint belongs to.
  final String seasonId;

  /// The series' title.
  final String title;

  /// The series' poster, when the detail had one.
  final String? cover;

  /// The zero-based position of the last-opened episode.
  final int episodeIndex;

  /// The seconds into that episode the checkpoint carried — the season
  /// page's ticks write it while the picture runs; an open-time write
  /// carries none, and a return to the season resumes from it.
  final double? positionSeconds;

  /// How many episodes the ladder had when the checkpoint was written.
  final int? total;

  /// Whether the picture reached the episode's end — the season page marks
  /// it on the station's own end event.
  final bool finished;

  /// When the checkpoint was written.
  final DateTime updatedAt;

  /// Whether the season's end event marked it finished. Opening the last
  /// episode is only a place to resume, not proof that it was watched.
  bool get completed => finished;
}

/// The preference prefix one archive's viewer-set opening and ending points
/// live under — the video page writes one per part, and the manifest gate
/// reviews the prefix as a computed key.
const String kVodSkipPrefix = 'vod.skip.';

/// One archive's viewer-set opening and ending points, in seconds.
@immutable
final class VodSkipPoints {
  /// Creates the points.
  const VodSkipPoints({this.headSeconds, this.tailSeconds});

  /// Where the archive's opening ends, or null when none was set.
  final double? headSeconds;

  /// Where the archive's ending starts, or null when none was set.
  final double? tailSeconds;

  /// Parses the stored JSON, or returns null — no points is the ordinary
  /// answer, and a malformed one reads as none.
  static VodSkipPoints? parse(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      return VodSkipPoints(
        headSeconds: (json['head'] as num?)?.toDouble(),
        tailSeconds: (json['tail'] as num?)?.toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

/// The seasons' checkpoints, latest first.
///
/// The season page writes one checkpoint per series on every episode open;
/// this notifier reads them out of the preference store and follows the
/// store's change stream, the same way the archive history does.
final class VodSeasonProgressController extends Notifier<List<VodSeasonProgress>> {
  StreamSubscription<Set<String>>? _subscription;

  /// The read after a write, settled like the history's — one read shortly
  /// after a burst of checkpoints instead of one per broadcast.
  Timer? _reload;

  @override
  List<VodSeasonProgress> build() {
    _subscription = StoragePrefs.watch().listen((keys) {
      if (!keys.any((key) => key.startsWith(kVodSeasonProgressPrefix))) return;
      _reload?.cancel();
      _reload = Timer(const Duration(milliseconds: 800), () => state = _read());
    });
    ref.onDispose(() {
      unawaited(_subscription?.cancel() ?? Future<void>.value());
      _reload?.cancel();
    });
    return _read();
  }

  /// Writes one series' checkpoint — the season page calls it at each
  /// episode open, so the shelf and the continue card never disagree. The
  /// end event marks it [completed], the mark a single-episode season
  /// needs before its checkpoint leaves the continue card.
  Future<void> save({
    required String seasonId,
    required String title,
    required int episodeIndex,
    String? cover,
    int? total,
    double? positionSeconds,
    bool completed = false,
  }) async {
    final key = '$kVodSeasonProgressPrefix$seasonId';
    final written = VodSeasonProgress(
      seasonId: seasonId,
      title: title,
      cover: cover,
      episodeIndex: episodeIndex,
      updatedAt: DateTime.now(),
      positionSeconds: positionSeconds,
      total: total,
      finished: completed,
    );
    try {
      await StoragePrefs.setString(
        key,
        jsonEncode({
          'title': title,
          if (cover != null && cover.isNotEmpty) 'cover': cover,
          'episodeIndex': episodeIndex,
          'total': ?total,
          'positionSeconds': ?positionSeconds,
          if (completed) 'completed': true,
          'updatedAt': written.updatedAt.millisecondsSinceEpoch,
        }),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
    await _prune(written: written);
  }

  /// Drops the oldest checkpoints once the shelf passes its limit, so a
  /// viewer who opens a hundred series does not keep a thousand entries.
  /// The in-memory shelf plus the entry just written decides — the
  /// prune runs after every checkpoint write and must not rescan the
  /// whole store each time.
  Future<void> _prune({required VodSeasonProgress written}) async {
    final merged = [written, ...state.where((entry) => entry.seasonId != written.seasonId)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final entry in merged.skip(kVodSeasonProgressLimit)) {
      try {
        await StoragePrefs.remove('$kVodSeasonProgressPrefix${entry.seasonId}');
      } on Object {
        // A preference; a closed store loses it.
      }
    }
  }

  /// Drops one series' checkpoint.
  Future<void> remove(String seasonId) async {
    try {
      await StoragePrefs.remove('$kVodSeasonProgressPrefix$seasonId');
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static List<VodSeasonProgress> _read() {
    final List<VodSeasonProgress> entries;
    try {
      entries = [
        for (final MapEntry(:key, :value) in StoragePrefs.snapshot().entries)
          if (key.startsWith(kVodSeasonProgressPrefix)) ?_parse(key, value),
      ];
    } on Object {
      return const [];
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  static VodSeasonProgress? _parse(String key, Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      final seasonId = key.substring(kVodSeasonProgressPrefix.length);
      final title = json['title'];
      final index = json['episodeIndex'];
      if (seasonId.isEmpty || title is! String || title.isEmpty || index is! num) return null;
      final updatedAt = (json['updatedAt'] as num?)?.toInt();
      return VodSeasonProgress(
        seasonId: seasonId,
        title: title,
        cover: json['cover'] is String ? json['cover'] as String : null,
        episodeIndex: index.toInt(),
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble(),
        total: json['total'] is num ? (json['total'] as num).toInt() : null,
        finished: json['completed'] == true,
        updatedAt: updatedAt == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(updatedAt),
      );
    } on Object {
      return null;
    }
  }
}

/// The seasons' continue checkpoints.
final vodSeasonProgressProvider = NotifierProvider<VodSeasonProgressController, List<VodSeasonProgress>>(
  VodSeasonProgressController.new,
);
