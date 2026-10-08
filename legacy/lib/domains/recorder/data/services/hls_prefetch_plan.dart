import 'dart:convert';

/// Only describes an unambiguous master; it never chooses a quality, language,
/// subtitle or camera for native. Other masters retain their existing path.
final class HlsPrefetchPlan {
  HlsPrefetchPlan._(List<Uri> sources) : sources = List.unmodifiable(sources);
  final List<Uri> sources;

  static HlsPrefetchPlan? fromMaster(String text, Uri source) {
    if (text.length > 4 * 1024 * 1024 || utf8.encode(text).length > 4 * 1024 * 1024) return null;
    final lines = const LineSplitter().convert(text).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') return null;
    Map<String, String>? variant;
    Map<String, String>? audio;
    Uri? video;
    var pendingVariant = false;
    var versionSeen = false;
    var independentSeen = false;
    try {
      for (final line in lines.skip(1)) {
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          if (variant != null || pendingVariant) return null;
          variant = _attributes(line.substring(18));
          if (variant.keys.any(
                (key) => !const {
                  'BANDWIDTH',
                  'AVERAGE-BANDWIDTH',
                  'RESOLUTION',
                  'CODECS',
                  'FRAME-RATE',
                  'AUDIO',
                  'CLOSED-CAPTIONS',
                }.contains(key),
              ) ||
              !RegExp(r'^[1-9]\d*$').hasMatch(variant['BANDWIDTH'] ?? '') ||
              (variant.containsKey('CLOSED-CAPTIONS') && variant['CLOSED-CAPTIONS'] != 'NONE')) {
            return null;
          }
          pendingVariant = true;
        } else if (line.startsWith('#EXT-X-MEDIA:')) {
          if (audio != null || pendingVariant) return null;
          audio = _attributes(line.substring(13));
          if (audio['TYPE'] != 'AUDIO' ||
              (audio['GROUP-ID'] ?? '').isEmpty ||
              (audio['NAME'] ?? '').isEmpty ||
              (audio['URI'] ?? '').isEmpty ||
              audio.keys.any(
                (key) => !const {
                  'TYPE',
                  'GROUP-ID',
                  'NAME',
                  'URI',
                  'DEFAULT',
                  'AUTOSELECT',
                  'LANGUAGE',
                  'CHANNELS',
                  'CHARACTERISTICS',
                }.contains(key),
              )) {
            return null;
          }
          for (final key in ['DEFAULT', 'AUTOSELECT']) {
            if (audio.containsKey(key) && !const {'YES', 'NO'}.contains(audio[key])) return null;
          }
        } else if (line.startsWith('#EXT-X-VERSION:')) {
          if (versionSeen || pendingVariant || !RegExp(r'^[1-9]\d*$').hasMatch(line.substring(15))) return null;
          versionSeen = true;
        } else if (line == '#EXT-X-INDEPENDENT-SEGMENTS') {
          if (independentSeen || pendingVariant) return null;
          independentSeen = true;
        } else if (line.startsWith('#')) {
          if (line.startsWith('#EXT')) return null;
        } else {
          if (!pendingVariant || video != null) return null;
          video = _resolve(source, line);
          pendingVariant = false;
        }
      }
      if (variant == null || video == null || pendingVariant) return null;
      final group = variant['AUDIO'];
      if (group == null) return audio == null ? HlsPrefetchPlan._([video]) : null;
      if (audio == null || group != audio['GROUP-ID']) return null;
      final audioUri = _resolve(source, audio['URI']!);
      if (audioUri == video) return null;
      return HlsPrefetchPlan._([video, audioUri]);
    } on FormatException {
      return null;
    }
  }

  static Uri _resolve(Uri source, String value) {
    final uri = source.resolve(value);
    if (!const {'http', 'https'}.contains(source.scheme) ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty ||
        source.hasFragment ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        value.isEmpty ||
        uri.toString().length > 65536 ||
        value.contains(RegExp(r'[\x00-\x20\x7f]')) ||
        (source.scheme == 'https' && uri.scheme != 'https')) {
      throw const FormatException('Invalid selected HLS URI');
    }
    return uri;
  }

  static Map<String, String> _attributes(String value) {
    final result = <String, String>{};
    final pattern = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,\s"]+)');
    var offset = 0;
    while (offset < value.length) {
      final match = pattern.matchAsPrefix(value, offset);
      if (match == null || result.containsKey(match.group(1))) throw const FormatException('Invalid HLS attributes');
      var text = match.group(2)!;
      if (text.startsWith('"')) text = text.substring(1, text.length - 1);
      result[match.group(1)!] = text;
      offset = match.end;
      if (offset == value.length) break;
      if (value[offset++] != ',' || offset == value.length) throw const FormatException('Invalid HLS separator');
    }
    return result;
  }
}
