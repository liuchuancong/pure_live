import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the CHZZK (Naver) live APIs.
abstract final class ChzzkParser {
  /// API host.
  static const String apiHost = 'api.chzzk.naver.com';

  /// Web origin.
  static const String origin = 'https://chzzk.naver.com';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// A channel id: 32 lower-case hex digits.
  static bool isChannelId(String value) => RegExp(r'^[0-9a-f]{32}$').hasMatch(value.trim());

  /// The channel page URL.
  static String roomUrl(String channelId) => '$origin/live/$channelId';

  /// Validates the `{code, content}` envelope and returns `content`; a
  /// null content is "not found" (the platform answers 200 for unknown
  /// ids).
  static Map<String, Object?>? content(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('chzzk $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('chzzk $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('chzzk $what: body is not an object');
    }
    final content = decoded['content'];
    if (content == null) {
      return null;
    }
    if (content is! Map<String, Object?>) {
      throw SiteApiChangedError('chzzk $what: content is not an object');
    }
    return content;
  }

  /// `/service/v1/channels/<id>` → the channel facts.
  static ({String id, String name, String? avatar, int? followers, bool openLive}) channel(
    String body, {
    required String channelId,
    int status = 200,
  }) {
    final content = ChzzkParser.content(body, status: status, what: 'channels');
    final id = content?['channelId']?.toString() ?? '';
    if (id.isEmpty) {
      throw SiteNotFoundError('chzzk: no channel $channelId');
    }
    if (id != channelId) {
      throw SiteApiChangedError('chzzk channels: asked $channelId, got $id');
    }
    return (
      id: id,
      name: content?['channelName']?.toString() ?? '',
      avatar: _image(content?['channelImageUrl']),
      followers: (content?['followerCount'] as num?)?.toInt(),
      openLive: content?['openLive'] == true,
    );
  }

  /// `/service/v3.1/channels/<id>/live-detail` → the live state and its
  /// HLS masters; null when the channel has no current live.
  static ({bool live, String title, String? cover, int? watching, DateTime? startedAt, List<String> masters})
  liveDetail(String body, {required String channelId, int status = 200}) {
    final content = ChzzkParser.content(body, status: status, what: 'live-detail');
    if (content == null) {
      return (live: false, title: '', cover: null, watching: null, startedAt: null, masters: const <String>[]);
    }
    final channel = content['channel'];
    if (channel is Map<String, Object?>) {
      final echoed = channel['channelId']?.toString();
      if (echoed != null && echoed != channelId) {
        throw SiteApiChangedError('chzzk live-detail: channel $echoed for $channelId');
      }
    }
    final statusText = content['status']?.toString();
    final live = statusText == 'OPEN';
    if (statusText != 'OPEN' && statusText != 'CLOSE' && statusText != 'CLOSED') {
      throw SiteApiChangedError('chzzk live-detail: status $statusText');
    }
    final openDate = content['openDate']?.toString();
    return (
      live: live,
      title: content['liveTitle']?.toString() ?? '',
      cover: _image(content['liveImageUrl'] ?? content['defaultThumbnailImageUrl']),
      watching: (content['concurrentUserCount'] as num?)?.toInt() ?? _parseCount(content['liveUserCount']),
      startedAt: live && openDate != null ? DateTime.tryParse(openDate) : null,
      masters: live ? _masters(content['livePlaybackJson']) : const <String>[],
    );
  }

  /// The HLS master URLs of a `livePlaybackJson` string: the HLS and
  /// LLHLS media of the playback payload, each once.
  static List<String> _masters(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return const [];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    final media = decoded is Map<String, Object?> ? decoded['media'] : null;
    if (media is! List) {
      return const [];
    }
    final masters = <String>[];
    final seen = <String>{};
    for (final item in media) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final protocol = item['protocol']?.toString();
      final id = item['mediaId']?.toString();
      if (protocol != 'HLS' || (id != 'HLS' && id != 'LLHLS')) {
        continue;
      }
      final url = item['path']?.toString() ?? '';
      if (url.startsWith('http') && seen.add(url)) {
        masters.add(url);
      }
    }
    return masters;
  }

  /// The room snapshot from the channel facts and live state.
  static LiveRoom room(
    ({String id, String name, String? avatar, int? followers, bool openLive}) owner,
    ({bool live, String title, String? cover, int? watching, DateTime? startedAt, List<String> masters}) live,
  ) => LiveRoom(
    platform: SiteIds.chzzk,
    roomId: owner.id,
    title: live.title.isEmpty ? owner.name : live.title,
    nick: owner.name,
    avatar: owner.avatar,
    cover: live.cover ?? owner.avatar,
    watching: live.watching,
    status: live.live
        ? LiveStatus.live
        : owner.openLive
        ? LiveStatus.live
        : LiveStatus.offline,
    startedAt: live.startedAt,
    data: live.live ? live.masters : null,
  );

  /// The play lines of a live room's masters: the HLS tiers, the LLHLS
  /// one labelled.
  static List<LivePlayLine> playLines(Object? masters, String channelId) {
    if (masters is! List) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    for (final (index, raw) in masters.indexed) {
      final url = raw?.toString() ?? '';
      if (!url.startsWith('http')) {
        continue;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: {'user-agent': headers['user-agent']!, 'referer': roomUrl(channelId)},
          format: StreamFormat.hls,
          codec: 'avc',
          lineId: index == 0 ? 'HLS' : 'HLS-$index',
        ),
      );
    }
    return lines;
  }

  static int? _parseCount(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    final text = value?.toString().replaceAll(',', '') ?? '';
    return int.tryParse(text);
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
