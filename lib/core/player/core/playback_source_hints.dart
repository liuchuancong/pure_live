import 'package:media_core/media_core.dart';

const String kPlaybackStreamFormatKey = 'pure_live.stream_format';

Map<String, Object?> playbackStreamFormatMetadata(String? formatName) =>
    formatName == null ? const <String, Object?>{} : <String, Object?>{kPlaybackStreamFormatKey: formatName};

String? declaredStreamFormatOf(PlayerSource source) {
  final value = source.metadata[kPlaybackStreamFormatKey];
  return value is String && value.isNotEmpty ? value : null;
}

bool isPrivatePlaybackInput(Uri uri) {
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase())) return true;
  var host = uri.host.toLowerCase();
  if (host == 'localhost' || host.startsWith('127.')) return true;
  // Uri may or may not keep the brackets on an IPv6 literal.
  if (host.startsWith('[') && host.endsWith(']')) host = host.substring(1, host.length - 1);
  return host == '::1';
}
