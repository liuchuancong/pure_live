import 'package:pure_live/core/iptv/models/channel.dart';
import 'package:pure_live/core/iptv/parsers/playlist_parse_result.dart';

/// Parses TXT playlists in genre format.
class TxtParser {
  static final RegExp _genreRegex = RegExp(r',\s*#genre#\s*$', caseSensitive: false);

  PlaylistParseResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    final errors = <String>[];

    String currentGroup = 'Uncategorized';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (_genreRegex.hasMatch(line)) {
        final group = line.split(',').first.trim();
        if (group.isNotEmpty && !group.contains('更新时间') && !group.contains('提示')) {
          currentGroup = group;
        }
        continue;
      }

      final commaIndex = line.indexOf(',');
      if (commaIndex == -1 || commaIndex == line.length - 1) continue;

      try {
        final name = line.substring(0, commaIndex).trim();
        final rawUrls = line.substring(commaIndex + 1).trim();

        if (name.isEmpty || rawUrls.isEmpty) continue;
        if (name.startsWith('—') || name.startsWith('[')) continue;

        final urlList = rawUrls.split('#');
        int sourceIndex = 1;

        for (final url in urlList) {
          final trimmedUrl = url.trim();
          if (trimmedUrl.isEmpty || !_isValidStreamUrl(trimmedUrl)) continue;
          final finalName = urlList.length > 1 ? '$name (线路$sourceIndex)' : name;
          final channel = _createChannel(name: finalName, url: trimmedUrl, group: currentGroup, providerId: providerId);
          channels.add(channel);
          sourceIndex++;
        }
      } catch (e) {
        errors.add('Line $i: Invalid channel $e');
      }
    }

    return PlaylistParseResult(channels: channels, errors: errors);
  }

  Channel _createChannel({
    required String name,
    required String url,
    required String group,
    required String providerId,
  }) {
    final uniqueKey = '${name}_$url';
    final channelId = '${providerId}_${uniqueKey.hashCode}';

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: null,
      tvgName: null,
      tvgLogo: null,
      groupTitle: group,
      channelNumber: null,
      streamUrl: url,
      streamType: StreamType.live,
    );
  }

  bool _isValidStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme) return false;

      final scheme = uri.scheme.toLowerCase();
      return const ['http', 'https', 'rtmp', 'rtsp', 'udp', 'mms', 'p2p'].contains(scheme);
    } catch (_) {
      return false;
    }
  }
}
