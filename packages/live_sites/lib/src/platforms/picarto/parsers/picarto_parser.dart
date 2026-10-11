import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Picarto channel APIs.
abstract final class PicartoParser {
  /// Private (inner) API host.
  static const String apiHost = 'ptvintern.picarto.tv';

  /// Public API host.
  static const String publicApiHost = 'api.picarto.tv';

  /// Web origin.
  static const String web = 'https://picarto.tv';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$web/',
  };

  /// Media headers of channel [name].
  static Map<String, String> mediaHeaders(String name) => {
    'user-agent': headers['user-agent']!,
    'origin': web,
    'referer': '$web/$name',
  };

  /// A channel name: letters, digits and underscores/dashes.
  static bool isChannelName(String value) => RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value.trim());

  /// The channel detail URL of [name].
  static Uri detailUrl(String name) => Uri.https(apiHost, '/api/channel/detail/$name');

  /// The channel page URL.
  static String roomPageUrl(String name) => '$web/$name';

  /// Validates a JSON body.
  static Map<String, Object?> root(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('picarto $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('picarto $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('picarto $what: body is not an object');
    }
    return decoded;
  }

  /// `channel/detail` → the room with its master playlist URL in `data`
  /// (the load-balancer edge plus the broadcast's stream name).
  static LiveRoom room(String body, {required String requestedId, int status = 200}) {
    final root = PicartoParser.root(body, status: status, what: 'channel/detail');
    if (root.containsKey('channel') && root['channel'] == null) {
      throw SiteNotFoundError('picarto channel/detail: no channel "$requestedId"');
    }
    final channel = root['channel'];
    if (channel is! Map<String, Object?>) {
      throw const SiteApiChangedError('picarto channel/detail: no channel object');
    }
    final name = channel['name']?.toString() ?? '';
    if (name.toLowerCase() != requestedId.trim().toLowerCase() || channel['private'] is! bool) {
      throw const SiteApiChangedError('picarto channel/detail: invalid channel');
    }
    final channelId = (channel['id'] as num?)?.toInt();
    final live = channel['online'] == true;
    final private = channel['private'] == true;
    Uri? master;
    if (live && !private) {
      final edge = root['getLoadBalancerUrl'] is Map<String, Object?>
          ? (root['getLoadBalancerUrl']! as Map<String, Object?>)['origin']?.toString() ?? ''
          : '';
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(edge)) {
        throw const SiteApiChangedError('picarto channel/detail: no load balancer edge');
      }
      final streams = root['getMultiStreams'] is Map<String, Object?>
          ? (root['getMultiStreams']! as Map<String, Object?>)['streams']
          : null;
      String? streamName;
      if (streams is List) {
        for (final entry in streams) {
          if (entry is Map<String, Object?> && (entry['channelId'] as num?)?.toInt() == channelId) {
            final candidate = entry['stream_name']?.toString() ?? '';
            if (RegExp(r'^[a-zA-Z0-9_+-]{1,150}$').hasMatch(candidate)) {
              streamName = candidate;
            }
            break;
          }
        }
      }
      if (streamName != null) {
        master = Uri.parse('https://$edge.picarto.tv/stream/hls/$streamName/index.m3u8');
      }
    }
    final categories = channel['categories'];
    final areaName = categories is List
        ? [
            for (final category in categories)
              if (category is Map<String, Object?> && category['name'] != null) category['name'].toString(),
          ].join(' / ')
        : null;
    final title = channel['title']?.toString() ?? '';
    return LiveRoom(
      platform: SiteIds.picarto,
      roomId: name,
      title: title,
      nick: name,
      avatar: _image(channel['avatar']),
      cover: _image(channel['image_thumbnail']),
      areaName: areaName,
      watching: (channel['viewers'] as num?)?.toInt(),
      status: live ? LiveStatus.live : LiveStatus.offline,
      restriction: private ? LiveRestriction.loginRequired : null,
      data: master,
    );
  }

  /// The play lines of a live room's master playlist.
  static List<LivePlayLine> playLines(Object? data, String name) {
    if (data is! Uri) {
      return const [];
    }
    return [
      LivePlayLine(
        url: data.toString(),
        headers: mediaHeaders(name),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'master',
      ),
    ];
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
