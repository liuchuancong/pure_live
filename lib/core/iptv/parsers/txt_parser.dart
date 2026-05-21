import 'package:pure_live/core/iptv/models/channel.dart';
import 'package:pure_live/core/iptv/parsers/playlist_parse_result.dart';

class TxtParser {
  const TxtParser();

  PlaylistParseResult parse(
    String content, {
    required String providerId,
  }) {
    final lines = content.split(RegExp(r'\r?\n'));

    final channels = <Channel>[];
    final errors = <String>[];

    String currentGroup = 'Default';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      try {
        final result = _parseLine(
          line,
          providerId,
          currentGroup,
        );

        if (result == null) continue;

        // group
        if (result.$1 != null) {
          currentGroup = result.$1!;
          continue;
        }

        // channel
        if (result.$2 != null) {
          channels.add(result.$2!);
        }
      } catch (e) {
        errors.add('Line ${i + 1}: $e');
      }
    }

    return PlaylistParseResult(
      channels: channels,
      errors: errors,
    );
  }

  /// return:
  /// (groupName, channel)
  (String?, Channel?)? _parseLine(
    String line,
    String providerId,
    String currentGroup,
  ) {
    final parts = line.split(',');

    if (parts.length < 2) return null;

    final first = parts[0].trim();
    final second = parts[1].trim();

    // channel line
    if (_isLiveLink(second)) {
      final channelId =
          '${providerId}_${first.hashCode}_${second.hashCode}';

      return (
        null,
        Channel(
          id: channelId,
          providerId: providerId,
          name: first,
          tvgName: first,
          groupTitle: currentGroup,
          streamUrl: second,
          streamType: StreamType.live,
        ),
      );
    }

    // group line
    return (
      first.isEmpty ? 'Group' : first,
      null,
    );
  }

  bool _isLiveLink(String link) {
    final lower = link.toLowerCase();

    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('rtmp://') ||
        lower.startsWith('rtsp://') ||
        lower.startsWith('udp://') ||
        lower.startsWith('rtp://') ||
        lower.startsWith('ws://') ||
        lower.startsWith('wss://');
  }
}