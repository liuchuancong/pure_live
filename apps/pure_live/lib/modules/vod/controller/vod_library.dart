import 'dart:async' show StreamSubscription, unawaited;
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
  Future<bool> toggle(VodSavedVideo video) async {
    final collected = contains(video.bvid);
    state = collected
        ? [
            for (final entry in state)
              if (entry.bvid != video.bvid) entry,
          ]
        : [video, ...state];
    await _save();
    return !collected;
  }

  /// Drops one archive.
  Future<void> remove(String bvid) async {
    state = [
      for (final entry in state)
        if (entry.bvid != bvid) entry,
    ];
    await _save();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kVodFavouritesKey, jsonEncode([for (final video in state) video.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
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

  @override
  List<VodHistoryEntry> build() {
    _subscription = StoragePrefs.watch().listen((keys) {
      if (keys.any((key) => key.startsWith(kVodProgressPrefix))) state = _read();
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return _read();
  }

  /// Drops one archive's entry.
  Future<void> remove(String bvid) async {
    // The prefix is a constant, the bvid is not: the manifest gate treats
    // this as a computed key and lists it for review instead of demanding a
    // static entry.
    final key = '$kVodProgressPrefix$bvid';
    try {
      await StoragePrefs.remove(key);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Drops every entry.
  Future<void> clear() async {
    for (final entry in state) {
      await remove(entry.bvid);
    }
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
