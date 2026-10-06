import 'package:media_core/media_core.dart';

const String kPlaybackStreamFormatKey = 'pure_live.stream_format';

/// A positive play-start the platform declared for this line (Bilibili
/// rotation/replay rooms carry `video.start`). It rides the source metadata so
/// the per-source engine hook can keep `force-seekable` on exactly for the
/// sources that must seek to it, and off for ordinary live where a seek can
/// only fail.
const String kPlaybackSeekStartKey = 'pure_live.seek_start_ms';

Map<String, Object?> playbackStreamFormatMetadata(String? formatName) =>
    formatName == null ? const <String, Object?>{} : <String, Object?>{kPlaybackStreamFormatKey: formatName};

/// Stamps a positive start offset into source metadata; nothing is stamped for
/// [Duration.zero] so ordinary live lines carry no key and read as "no declared
/// start".
Map<String, Object?> playbackSeekStartMetadata(Duration startAt) =>
    startAt > Duration.zero ? <String, Object?>{kPlaybackSeekStartKey: startAt.inMilliseconds} : const {};

String? declaredStreamFormatOf(PlayerSource source) {
  final value = source.metadata[kPlaybackStreamFormatKey];
  return value is String && value.isNotEmpty ? value : null;
}

/// Whether the platform declared a positive start for this line, so a seek to
/// it is meaningful and the source must stay force-seekable.
bool hasDeclaredSeekStart(PlayerSource source) {
  final value = source.metadata[kPlaybackSeekStartKey];
  return value is int && value > 0;
}

bool isPrivatePlaybackInput(Uri uri) {
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return true;
  var host = uri.host.toLowerCase();
  if (host == 'localhost' || host.startsWith('127.')) return true;
  // Uri may or may not keep the brackets on an IPv6 literal.
  if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
  return host == '::1';
}
