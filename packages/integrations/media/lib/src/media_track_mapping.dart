// Module: lib/src/media_track_mapping.dart
// Purpose: Converts the platform MediaTrack mirror to and from media_core's MediaTrack.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/adr/0016-platform-media-track-mirror.md, including its W3 amendment. The mapping is written as
// explicit field listing in both directions on purpose: when either side adds a field, this file fails to
// compile or fails its test rather than quietly dropping data on the way into the player.
//
// Two differences the mirror has to bridge: media_core types a track's essence as MediaTrackType and wraps
// request headers in a SourceHeaders value object, while the platform mirror used a plain map.

import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

/// Platform essence label to the kernel's.
core.MediaTrackType toCoreTrackType(platform.MediaTrackType kind) => switch (kind) {
  platform.MediaTrackType.video => core.MediaTrackType.video,
  platform.MediaTrackType.audio => core.MediaTrackType.audio,
  platform.MediaTrackType.subtitle => core.MediaTrackType.subtitle,
};

/// Kernel essence label back to the platform's.
platform.MediaTrackType toPlatformTrackType(core.MediaTrackType kind) => switch (kind) {
  core.MediaTrackType.video => platform.MediaTrackType.video,
  core.MediaTrackType.audio => platform.MediaTrackType.audio,
  core.MediaTrackType.subtitle => platform.MediaTrackType.subtitle,
};

/// One platform track into the kernel's shape.
///
/// An empty header map becomes null rather than an empty SourceHeaders: the kernel treats absent headers as
/// "inherit the source's", while an empty set would mean "send none", which is a different request.
core.MediaTrack toCoreTrack(platform.MediaTrack track) {
  return core.MediaTrack(
    uri: track.uri,
    kind: toCoreTrackType(track.kind),
    headers: track.headers.isEmpty ? null : core.SourceHeaders(track.headers),
    mimeType: track.mimeType,
    codec: track.codec,
    bitrate: track.bitrate,
    language: track.language,
    startOffset: track.startOffset,
    metadata: track.metadata,
  );
}

/// One kernel track back into the platform mirror, for a ticket the kernel produced or amended.
platform.MediaTrack toPlatformTrack(core.MediaTrack track) {
  final headers = track.headers;
  return platform.MediaTrack(
    uri: track.uri,
    kind: toPlatformTrackType(track.kind),
    headers: headers == null ? const <String, String>{} : Map<String, String>.from(headers.values),
    mimeType: track.mimeType,
    codec: track.codec,
    bitrate: track.bitrate,
    language: track.language,
    startOffset: track.startOffset,
    metadata: track.metadata,
  );
}
