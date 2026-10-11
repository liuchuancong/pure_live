// Module: lib/src/models/media/media_track/media_track.dart
// Purpose: MediaTrack, split out of the file that bundled it (see package-architecture.md
// §2.1): one public type per file, and the file in a folder of its own so anything generated for
// it lands beside it.
// Author: liuchuancong
// Created: 2026-10-11

import '../../../support/json.dart';
import '../media_track_type/media_track_type.dart';

/// One stream inside a ticket: video essence, audio essence or subtitle.
final class MediaTrack {
  const MediaTrack({
    required this.uri,
    required this.kind,
    this.headers = const <String, String>{},
    this.mimeType,
    this.codec,
    this.bitrate,
    this.language,
    this.startOffset,
    this.metadata = const <String, Object?>{},
  });

  factory MediaTrack.fromJson(Map<String, Object?> json) {
    return MediaTrack(
      uri: Uri.parse(requireString(json, 'uri', 'media_ticket')),
      kind: enumByName(MediaTrackType.values, json['kind'] as String?) ?? MediaTrackType.video,
      headers: stringMapField(json['headers']),
      mimeType: json['mimeType'] as String?,
      codec: json['codec'] as String?,
      bitrate: (json['bitrate'] as num?)?.toInt(),
      language: json['language'] as String?,
      startOffset: parseDurationMs(json['startOffsetMs']),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final Uri uri;

  /// Which essence this track carries, not what the resource as a whole is.
  final MediaTrackType kind;

  /// Per-stream request headers; DASH and HLS essences routinely need their own.
  final Map<String, String> headers;
  final String? mimeType;
  final String? codec;
  final int? bitrate;
  final String? language;
  final Duration? startOffset;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uri': uri.toString(),
      'kind': kind.name,
      if (headers.isNotEmpty) 'headers': headers,
      if (mimeType != null) 'mimeType': mimeType,
      if (codec != null) 'codec': codec,
      if (bitrate != null) 'bitrate': bitrate,
      if (language != null) 'language': language,
      if (startOffset != null) 'startOffsetMs': durationMs(startOffset),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
