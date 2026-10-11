import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Steam Broadcast community APIs.
abstract final class SteamBroadcastParser {
  /// The Steam 64-bit account base for the mini profile path.
  static final BigInt accountBase = BigInt.parse('76561197960265728');

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://steamcommunity.com/',
  };

  /// A Steam id: 17 digits starting with 7656.
  static bool isSteamId(String value) => RegExp(r'^7656\d{13}$').hasMatch(value.trim());

  /// The mini profile URL of [steamId].
  static Uri profileUrl(String steamId) =>
      Uri.https('steamcommunity.com', '/miniprofile/${BigInt.parse(steamId) - accountBase}/json');

  /// `getbroadcastmpd` of [steamId]'s current broadcast.
  static Uri mpdUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastmpd/', {
    'broadcastid': '0',
    'steamid': steamId,
    'viewertoken': '0',
    'sessionid': '',
  });

  /// `getbroadcastinfo` of [steamId]'s current broadcast.
  static Uri infoUrl(String steamId) => Uri.https('steamcommunity.com', '/broadcast/getbroadcastinfo/', {
    'steamid': steamId,
    'broadcastid': '0',
    'location': '5',
  });

  /// The watch page of [steamId].
  static String watchUrl(String steamId) => 'https://steamcommunity.com/broadcast/watch/$steamId';

  /// Media headers of [steamId].
  static Map<String, String> mediaHeaders(String steamId) => {
    'user-agent': headers['user-agent']!,
    'referer': watchUrl(steamId),
  };

  /// The mini profile → the broadcaster's name and avatar.
  static ({String name, String avatar}) profile(String body, {required String steamId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast miniprofile: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast miniprofile: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast miniprofile: body is not an object');
    }
    final name = decoded['persona_name'];
    if (name is! String) {
      throw const SiteApiChangedError('steambroadcast miniprofile: no persona_name');
    }
    return (name: name, avatar: decoded['avatar_url']?.toString() ?? '');
  }

  /// `getbroadcastmpd` → the state, restriction, title, viewers and (for
  /// ready broadcasts) the HLS master. A missing/non-text `success` or
  /// `title` is an API change.
  static ({
    LiveStatus status,
    LiveRestriction? restriction,
    String title,
    int? viewers,
    String? broadcastId,
    String? master,
  })
  broadcast(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast getbroadcastmpd: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: body is not an object');
    }
    final success = decoded['success']?.toString().toLowerCase();
    final title = decoded['title']?.toString() ?? '';
    if (success == null) {
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: no success');
    }
    final replay = decoded['is_replay'] == true;
    final (state, restriction) = switch (success) {
      'ready' => (replay ? LiveStatus.replay : LiveStatus.live, null),
      'missing_subscription' => (LiveStatus.live, LiveRestriction.subscribersOnly),
      'unavailable' || 'offline' || 'not_live' || 'no_broadcast' => (LiveStatus.offline, null),
      'user_restricted' => (LiveStatus.banned, null),
      _ => (LiveStatus.unknown, null),
    };
    String? master;
    final hls = decoded['hls_url']?.toString() ?? '';
    if (success == 'ready' && hls.startsWith('http')) {
      final cdn = decoded['cdn_auth_url_parameters']?.toString() ?? '';
      master = cdn.isEmpty ? hls : '$hls$cdn';
    }
    return (
      status: state,
      restriction: restriction,
      title: title,
      viewers: (decoded['num_viewers'] as num?)?.toInt(),
      broadcastId: decoded['broadcastid']?.toString(),
      master: master,
    );
  }

  /// `getbroadcastinfo` → the live facts (the refresh path). `success` 42
  /// is offline; 1 with `is_online` is live or a replay.
  static ({LiveStatus status, String title, String? cover, int? viewers}) info(
    String body, {
    required String steamId,
    int status = 200,
  }) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('steambroadcast getbroadcastinfo: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: body is not an object');
    }
    final success = (decoded['success'] as num?)?.toInt();
    if (success != 1 && success != 42) {
      throw const SiteApiChangedError('steambroadcast getbroadcastinfo: bad success');
    }
    final online = success == 1 && decoded['is_online'] == true;
    if (!online) {
      return (status: LiveStatus.offline, title: '', cover: null, viewers: null);
    }
    final game = decoded['app_title']?.toString() ?? '';
    final title = decoded['title']?.toString() ?? '';
    final thumbnail = decoded['thumbnail_url']?.toString() ?? '';
    return (
      status: decoded['is_replay'] == true ? LiveStatus.replay : LiveStatus.live,
      title: title.isEmpty ? game : title,
      cover: _thumbnail(thumbnail, game),
      viewers: (decoded['viewer_count'] as num?)?.toInt(),
    );
  }

  /// Builds a room from the clip facts.
  static LiveRoom room({
    required String steamId,
    required LiveStatus status,
    required ({String name, String avatar}) profile,
    String title = '',
    String? cover,
    int? viewers,
    LiveRestriction? restriction,
    String? master,
  }) => LiveRoom(
    platform: SiteIds.steamBroadcast,
    roomId: steamId,
    title: title,
    nick: profile.name,
    avatar: profile.avatar.isEmpty ? null : profile.avatar,
    cover: cover,
    watching: viewers,
    status: status,
    restriction: restriction,
    data: master,
  );

  /// The play lines of a ready broadcast's master.
  static List<LivePlayLine> playLines(Object? data, String steamId) {
    if (data is! String || !data.startsWith('http')) {
      return const [];
    }
    return [
      LivePlayLine(url: data, headers: mediaHeaders(steamId), format: StreamFormat.hls, codec: 'avc', lineId: 'master'),
    ];
  }

  /// The thumbnail rule: Steam writes paths that need the hash image host.
  static String? _thumbnail(String raw, String game) {
    if (raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http')) {
      return raw;
    }
    return 'https://cdn.cloudflare.steamstatic.com/steam/apps/$raw';
  }
}
