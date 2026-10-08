// Module: lib/src/ticket_source.dart
// Purpose: Turns a platform MediaTicket into the media_core MediaSource the planner and kernel consume.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/media-contract.md section 1 (the pipeline) and docs/adr/0016-platform-media-track-mirror.md.
// This is the platform-to-kernel edge: the ticket says what to play and under what policy, the kernel's
// MediaSource says what streams exist. Nothing here decides how to play it - planning, adapter selection and
// recovery all stay inside media_core (docs/adr/0020-media-core-owns-recovery.md).

import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'media_track_mapping.dart';

/// The kernel source for one ticket.
core.MediaSource toCoreSource(platform.MediaTicket ticket) {
  final live = _isLive(ticket);
  final tracks = ticket.tracks;

  if (tracks.isEmpty) {
    return core.ProgressiveMediaSource(track: _trackFromTicketUrl(ticket, live), live: live);
  }

  final video = <core.MediaTrack>[];
  final audio = <core.MediaTrack>[];
  final subtitle = <core.MediaTrack>[];
  for (final track in tracks) {
    final mapped = toCoreTrack(track);
    if (track.kind == platform.MediaTrackType.video) {
      video.add(mapped);
    } else if (track.kind == platform.MediaTrackType.audio) {
      audio.add(mapped);
    } else {
      subtitle.add(mapped);
    }
  }

  // One essence is the progressive case whatever it carries; a composite is for a source that named several.
  if (tracks.length == 1) {
    return core.ProgressiveMediaSource(track: toCoreTrack(tracks.single), live: live);
  }
  // Subtitles alone are not playable: CompositeMediaSource asserts at least one video or audio track, so a
  // ticket that only listed caption streams falls back to its own url.
  if (video.isEmpty && audio.isEmpty) {
    return core.ProgressiveMediaSource(track: _trackFromTicketUrl(ticket, live), live: live);
  }

  return core.CompositeMediaSource(videoTracks: video, audioTracks: audio, subtitleTracks: subtitle, live: live);
}

/// Whether the resource is a running stream rather than a fixed file.
bool _isLive(platform.MediaTicket ticket) => ticket.kind == platform.MediaKind.live || ticket.metadata.isLive;

/// A track for a ticket that named its streams only by url.
///
/// Music gets audio: a bare url with no essence list otherwise reaches the kernel as video, which makes an
/// audio-only source pick a video renderer it has nothing to draw.
core.MediaTrack _trackFromTicketUrl(platform.MediaTicket ticket, bool live) {
  return core.MediaTrack(
    uri: ticket.uri,
    kind: ticket.kind == platform.MediaKind.music ? core.MediaTrackType.audio : core.MediaTrackType.video,
    headers: ticket.headers.isEmpty ? null : core.SourceHeaders(ticket.headers),
    metadata: <String, Object?>{
      'platform.media_kind': ticket.kind.name,
      'platform.protocol': ticket.protocol.name,
      if (live) 'platform.live': true,
    },
  );
}
