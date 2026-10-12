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

  /// Largest `api/search` page size 3.x served.
  static const int maxPageSize = 60;

  /// Longest keyword `api/search` takes; a longer one is cut.
  static const int maxKeywordLength = 100;

  /// The `api/search` (`searchProfiles`) URL for [keyword] at [page] of
  /// [pageSize]: the channel search the site's own page uses. The keyword is
  /// trimmed and cut to [maxKeywordLength], the page floored at one.
  static Uri searchUrl(String keyword, {required int page, required int pageSize}) {
    final text = keyword.trim();
    return Uri.https(apiHost, '/api/search', {
      'first': '$pageSize',
      'page': '${page < 1 ? 1 : page}',
      'q': text.length > maxKeywordLength ? text.substring(0, maxKeywordLength) : text,
      'type': 'searchProfiles',
      'tag_search': 'false',
    });
  }

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
    final channelId = SiteCounts.integer(channel['id']);
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
          if (entry is Map<String, Object?> && SiteCounts.integer(entry['channelId']) == channelId) {
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
      watching: SiteCounts.integer(channel['viewers']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      restriction: private ? LiveRestriction.private : null,
      data: <String, Object?>{'channelId': ?channelId, 'master': ?master},
    );
  }

  /// The play lines of a live room's master playlist.
  static List<LivePlayLine> playLines(Object? data, String name) {
    final master = data is Map<String, Object?> ? data['master'] : null;
    if (master is! Uri) {
      return const [];
    }
    return [
      LivePlayLine(
        url: master.toString(),
        headers: mediaHeaders(name),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'master',
      ),
    ];
  }

  /// The numeric channel id of a room, from its detail; null until a detail
  /// has answered. The chat socket names the room by it.
  static int? channelIdOf(Object? data) => data is Map<String, Object?> ? _asInt(data['channelId']) : null;

  /// An `api/search` (`searchProfiles`) page: channel profiles, live and
  /// offline, one per name, each at most [pageSize]. A profile with no valid
  /// name, id or online flag, or with negative followers, is left out; a page
  /// with rows but none usable is a changed endpoint. The profile's title is
  /// its name (search rows carry no stream title), and the bio and follower
  /// count the reduced room model has no field for are dropped.
  static List<LiveRoom> search(String body, {required int pageSize, int status = 200}) {
    final root = PicartoParser.root(body, status: status, what: 'search');
    final rows = SiteJson.object(root['searchProfiles'])['data'];
    if (rows is! List || rows.length > pageSize) {
      throw SiteApiChangedError('picarto search: no searchProfiles.data of at most $pageSize');
    }
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    for (final profile in SiteJson.objects(rows)) {
      final id = SiteCounts.integer(profile['id']);
      final followers = SiteCounts.integer(profile['follower_count']);
      final name = SiteText.trimmed(profile['name']);
      if (!isChannelName(name) ||
          id == null ||
          id <= 0 ||
          profile['online'] is! bool ||
          (followers != null && followers < 0)) {
        continue;
      }
      usable++;
      rooms.putIfAbsent(
        name.toLowerCase(),
        () => LiveRoom(
          platform: SiteIds.picarto,
          roomId: name,
          title: name,
          nick: name,
          avatar: _image(profile['avatar']),
          status: profile['online'] == true ? LiveStatus.live : LiveStatus.offline,
        ),
      );
    }
    if (rows.isNotEmpty && usable == 0) {
      throw const SiteApiChangedError('picarto search: no usable profile');
    }
    return List.unmodifiable(rooms.values);
  }

  static int? _asInt(Object? value) => value is int ? value : int.tryParse('$value');

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
