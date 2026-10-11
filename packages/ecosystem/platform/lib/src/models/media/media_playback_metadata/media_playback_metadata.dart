// Module: lib/src/models/media/media_playback_metadata/media_playback_metadata.dart
// Purpose: MediaPlaybackMetadata, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';

/// Descriptive fields for a UI or a media session. No playback state.
final class MediaPlaybackMetadata {
  const MediaPlaybackMetadata({
    this.title,
    this.artist,
    this.album,
    this.cover,
    this.duration,
    this.isLive = false,
    this.extra = const <String, Object?>{},
  });

  factory MediaPlaybackMetadata.fromJson(Map<String, Object?> json) {
    return MediaPlaybackMetadata(
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      cover: json['cover'] as String?,
      duration: parseDurationMs(json['durationMs']),
      isLive: json['isLive'] as bool? ?? false,
      extra: asObjectMap(json['extra']),
    );
  }

  final String? title;
  final String? artist;
  final String? album;
  final String? cover;
  final Duration? duration;
  final bool isLive;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (cover != null) 'cover': cover,
      if (duration != null) 'durationMs': durationMs(duration),
      if (isLive) 'isLive': true,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }
}
