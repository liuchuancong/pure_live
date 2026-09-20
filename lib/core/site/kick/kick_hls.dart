import 'dart:convert';

class KickHlsVariant {
  const KickHlsVariant({required this.uri, required this.height, required this.frameRate, required this.bandwidth});

  final Uri uri;
  final int height;
  final double frameRate;
  final int bandwidth;
}

class KickHls {
  const KickHls._();

  static List<KickHlsVariant> parse(Uri source, String text) {
    _mediaUri(source.toString());
    if (text.length > 4 * 1024 * 1024 || utf8.encode(text).length > 4 * 1024 * 1024) {
      throw const FormatException('Kick HLS master exceeds byte budget');
    }
    final lines = const LineSplitter().convert(text).map((line) => line.trim()).where((line) => line.isNotEmpty);
    final iterator = lines.iterator;
    if (!iterator.moveNext() || iterator.current != '#EXTM3U') throw const FormatException('Expected Kick HLS master');
    Map<String, String>? pending;
    final result = <KickHlsVariant>[];
    final seen = <Uri>{};
    while (iterator.moveNext()) {
      final line = iterator.current;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending != null || result.length >= 32) throw const FormatException('Invalid Kick HLS variant count');
        pending = _attributes(line.substring(18));
        continue;
      }
      if (line.startsWith('#')) {
        if (pending != null) throw const FormatException('Missing Kick HLS variant URI');
        continue;
      }
      if (pending == null) throw const FormatException('Unexpected Kick HLS URI');
      final resolution = pending['RESOLUTION'] ?? '';
      final match = RegExp(r'^[1-9][0-9]{0,4}x([1-9][0-9]{0,4})$').firstMatch(resolution);
      final bandwidth = int.tryParse(pending['BANDWIDTH'] ?? '');
      final frameRate = double.tryParse(pending['FRAME-RATE'] ?? '') ?? 0;
      if (match == null || bandwidth == null || bandwidth <= 0 || !frameRate.isFinite || frameRate < 0) {
        throw const FormatException('Invalid Kick HLS variant metadata');
      }
      final uri = _mediaUri(source.resolve(line).toString());
      if (!seen.add(uri)) throw const FormatException('Duplicate Kick HLS variant');
      result.add(
        KickHlsVariant(uri: uri, height: int.parse(match.group(1)!), frameRate: frameRate, bandwidth: bandwidth),
      );
      pending = null;
    }
    if (pending != null || result.isEmpty) throw const FormatException('Incomplete Kick HLS master');
    return List.unmodifiable(result);
  }

  static Uri _mediaUri(String raw) {
    if (raw.isEmpty || raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const FormatException('Invalid Kick media URL');
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'live-video.net' || host.endsWith('.live-video.net'))) {
      throw const FormatException('Invalid Kick media host');
    }
    return uri;
  }

  static Map<String, String> _attributes(String text) {
    final values = <String, String>{};
    final pattern = RegExp(r'([A-Z0-9-]+)=("[^"\r\n\x00]*"|[^,\s"]+)(?:,|$)');
    var offset = 0;
    while (offset < text.length) {
      final match = pattern.matchAsPrefix(text, offset);
      if (match == null || values.containsKey(match[1])) throw const FormatException('Malformed Kick HLS attributes');
      final value = match[2]!;
      values[match[1]!] = value.startsWith('"') ? value.substring(1, value.length - 1) : value;
      offset = match.end;
    }
    if (text.endsWith(',')) throw const FormatException('Incomplete Kick HLS attributes');
    return values;
  }
}
