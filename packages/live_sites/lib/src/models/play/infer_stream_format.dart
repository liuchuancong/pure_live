import 'package:live_sites/src/models/enums/live_stream_format.dart';

/// Infers a stream's container from its URL: suffix or scheme to enum.
///
/// Returns null when nothing in the URL says anything (the caller then owns
/// the decision — probing, or `LiveStreamFormat.other`). Never fabricates a
/// format (MODELS.md §2.4).
LiveStreamFormat? inferStreamFormat(String url) {
  final uri = Uri.tryParse(url);
  final path = (uri?.path ?? url).toLowerCase();
  final scheme = (uri?.scheme ?? '').toLowerCase();

  // udpxy relays multicast as HTTP paths (/udp/..., /rtp/...).
  if (path.contains('/udp/') || path.contains('/rtp/')) {
    return LiveStreamFormat.mpegts;
  }

  const bySuffix = <String, LiveStreamFormat>{
    '.m3u8': LiveStreamFormat.hls,
    '.flv': LiveStreamFormat.flv,
    '.mpd': LiveStreamFormat.dash,
    '.ts': LiveStreamFormat.mpegts,
    '.mp4': LiveStreamFormat.mp4,
  };
  for (final entry in bySuffix.entries) {
    if (path.endsWith(entry.key)) return entry.value;
  }

  return switch (scheme) {
    'udp' => LiveStreamFormat.udp,
    'rtp' => LiveStreamFormat.rtp,
    'rtsp' => LiveStreamFormat.rtsp,
    'rtmp' || 'rtmps' => LiveStreamFormat.rtmp,
    _ => null,
  };
}
