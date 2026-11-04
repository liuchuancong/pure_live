import 'package:live_vod/live_vod.dart' show VodDashVideo, VodPlayInfo;
import 'package:media_core/media_core.dart';

/// The answer's DASH pair as one composite source, or null when it carries no
/// usable pair or the requested definition leaves no picture.
///
/// The picture and the sound arrive as two essences; media_core joins them
/// (mpv through its external-audio channel, ExoPlayer through its native
/// merging). An engine that cannot join them throws `UnsupportedError` from
/// `openMedia`, which is the cue to ask for the muxed answer instead.
MediaSource? vodDashSourceOf(VodPlayInfo info, {required int maxQuality}) {
  if (!info.hasDash) return null;
  final video = vodDashVideoOf(info, maxQuality: maxQuality);
  final audio = info.bestAudio;
  if (video == null || audio == null) return null;
  final headers = info.headers.isEmpty ? null : SourceHeaders(info.headers);
  return CompositeMediaSource(
    videoTracks: [
      MediaTrack.of(
        uri: Uri.parse(video.url),
        kind: MediaTrackType.video,
        headers: headers,
        mimeType: 'video/mp4',
        codec: video.codec.isEmpty ? null : video.codec,
        bitrate: video.bandwidth,
      ),
    ],
    audioTracks: [
      MediaTrack.of(
        uri: Uri.parse(audio.url),
        kind: MediaTrackType.audio,
        headers: headers,
        mimeType: 'audio/mp4',
        bitrate: audio.bandwidth,
      ),
    ],
  );
}

/// The picture to show for [maxQuality]: the best definition that does not
/// exceed it, AVC preferred, then HEVC, then AV1 — the order the engines can
/// decode, not the order the ladder lists them in.
VodDashVideo? vodDashVideoOf(VodPlayInfo info, {required int maxQuality}) {
  if (info.videos.isEmpty) return null;
  final fitting = [
    for (final video in info.videos)
      if (video.quality <= maxQuality) video,
  ];
  final pool = fitting.isEmpty ? [...info.videos] : fitting;
  int rank(VodDashVideo video) {
    final codec = video.codec.toLowerCase();
    final codecRank = video.codecId == 7 || codec.startsWith('avc')
        ? 3
        : video.codecId == 12 || codec.startsWith('hev') || codec.startsWith('hvc')
        ? 2
        : video.codecId == 13 || codec.startsWith('av01')
        ? 1
        : 0;
    return codecRank * 100000000 + video.quality * 10000 + ((video.bandwidth ?? 0) ~/ 1000);
  }

  pool.sort((a, b) => rank(b).compareTo(rank(a)));
  return pool.first;
}
