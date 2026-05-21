import 'package:pure_live/core/iptv/models/channel.dart';
import 'package:pure_live/core/iptv/parsers/playlist_parse_result.dart';

/// Parses M3U and M3U Plus playlist formats.
///
/// Supports:
/// - Standard M3U (#EXTM3U / #EXTINF)
/// - M3U Plus extended attributes (tvg-id, tvg-name, tvg-logo, group-title, etc.)
/// - Xtream Codes style attributes (tvg-chno, tvg-shift)
/// - Multiple URL formats (HTTP, HTTPS, RTMP, RTSP, UDP)
class M3uParser {
  /// Parse M3U content from a string.
  PlaylistParseResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    final errors = <String>[];

    if (lines.isEmpty || !lines.first.trim().startsWith('#EXTM3U')) {
      errors.add('Missing #EXTM3U header');
    }

    String? currentExtInf;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty || line == '#EXTM3U') continue;

      // Skip global EXTM3U attributes line
      if (line.startsWith('#EXTM3U ')) continue;

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
        continue;
      }

      // Skip other directives
      if (line.startsWith('#')) continue;

      // This should be a URL
      if (currentExtInf != null) {
        try {
          final channel = _parseEntry(currentExtInf, line, providerId);
          if (channel != null) channels.add(channel);
        } catch (e) {
          errors.add('Line $i: $e');
        }
        currentExtInf = null;
      }
    }

    return PlaylistParseResult(channels: channels, errors: errors);
  }

  Channel? _parseEntry(String extInf, String url, String providerId) {
    if (url.isEmpty) return null;

    // Parse #EXTINF:-1 tvg-id="..." tvg-name="..." ... , Channel Name
    final attrs = _parseAttributes(extInf);
    final displayName = _parseDisplayName(extInf);

    if (displayName.isEmpty && attrs['tvg-name'] == null) return null;

    final name = displayName.isNotEmpty ? displayName : attrs['tvg-name']!;

    // Generate a stable ID from provider + tvg-id or URL
    final tvgId = attrs['tvg-id'];
    final channelId = tvgId != null && tvgId.isNotEmpty ? '${providerId}_$tvgId' : '${providerId}_${url.hashCode}';

    // Parse channel number
    int? channelNumber;
    final chnoStr = attrs['tvg-chno'];
    if (chnoStr != null && chnoStr.isNotEmpty) {
      channelNumber = int.tryParse(chnoStr);
    }

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      tvgLogo: _emptyToNull(attrs['tvg-logo']),
      groupTitle: _emptyToNull(attrs['group-title']),
      channelNumber: channelNumber,
      streamUrl: url,
      streamType: _inferStreamType(attrs, url),
    );
  }

  /// Parse M3U Plus extended attributes from an #EXTINF line.
  /// Example: #EXTINF:-1 tvg-id="ESPN.us" tvg-name="ESPN HD" group-title="Sports",ESPN HD
  Map<String, String> _parseAttributes(String extInf) {
    final attrs = <String, String>{};

    // Match key="value" pairs
    final regex = RegExp(r'([\w-]+)="([^"]*)"');
    for (final match in regex.allMatches(extInf)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
  }

  /// Extract the display name (after the last comma in #EXTINF line).
  String _parseDisplayName(String extInf) {
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex == -1) return '';
    return extInf.substring(commaIndex + 1).trim();
  }

  StreamType _inferStreamType(Map<String, String> attrs, String url) {
    final groupTitle = (attrs['group-title'] ?? '').toLowerCase();
    if (groupTitle.contains('vod') || groupTitle.contains('movie')) {
      return StreamType.vod;
    }
    if (groupTitle.contains('series')) {
      return StreamType.series;
    }
    // Xtream Codes URL patterns
    if (url.contains('/movie/')) return StreamType.vod;
    if (url.contains('/series/')) return StreamType.series;
    return StreamType.live;
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

/// Result of parsing an M3U playlist.
class M3uResult {
  final List<Channel> channels;
  final List<String> errors;

  const M3uResult({required this.channels, this.errors = const []});

  bool get hasErrors => errors.isNotEmpty;
  int get channelCount => channels.length;
}
