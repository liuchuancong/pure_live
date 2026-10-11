import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Missevan (猫耳 FM) live APIs.
abstract final class MissevanParser {
  /// API request headers.
  static const Map<String, String> headers = {
    'referer': 'https://fm.missevan.com/',
    'origin': 'https://fm.missevan.com',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  };

  /// The `live/{id}` URL.
  static Uri detailUrl(String roomId) => Uri.https('fm.missevan.com', '/api/v2/live/$roomId');

  /// Validates the envelope (`code` 0) and returns the root; HTTP 404 and
  /// the unknown-room code are "not found".
  static Map<String, Object?> checked(String body, {required String roomId, int status = 200}) {
    switch (status) {
      case 200:
        break;
      case 401 || 403:
        throw SiteRiskControlError('missevan live/$roomId: HTTP $status');
      case 404:
        throw SiteNotFoundError('missevan live/$roomId: HTTP 404');
      case 429:
        throw SiteRateLimitedError('missevan live/$roomId: HTTP 429');
      default:
        throw SiteApiChangedError('missevan live/$roomId: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('missevan: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: body is not an object');
    }
    final code = (decoded['code'] as num?)?.toInt();
    if (code == null) {
      throw const SiteApiChangedError('missevan: no code');
    }
    if (code == 500030004) {
      throw SiteNotFoundError('missevan live/$roomId: room not found');
    }
    if (code != 0) {
      throw SiteApiChangedError('missevan live/$roomId: code $code');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: no data object');
    }
    return data;
  }

  /// `live/{id}` → the room with its catalog, state and pull URLs.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final data = checked(body, roomId: roomId, status: status);
    final row = data['room'];
    if (row is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: live.room missing');
    }
    final id = row['room_id']?.toString() ?? '';
    if (id != roomId) {
      throw SiteApiChangedError('missevan live/$roomId answered room $id');
    }
    final state = row['status'];
    final open = state is Map<String, Object?> ? (state['open'] as num?)?.toInt() : null;
    final live = open == 1;
    final statistics = row['statistics'];
    final score = statistics is Map<String, Object?> ? (statistics['score'] as num?)?.toInt() : null;
    final creator = data['creator'];
    final creatorMap = creator is Map<String, Object?> ? creator : const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.missevan,
      roomId: roomId,
      title: row['name']?.toString() ?? '',
      nick: row['creator_username']?.toString() ?? creatorMap['username']?.toString() ?? '',
      avatar: image(creatorMap['iconurl'] ?? row['creator_iconurl']),
      cover: image(row['cover_url']),
      areaName: row['catalog_name']?.toString(),
      watching: score,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedAt(state is Map<String, Object?> ? state['open_time'] : null) : null,
      data: live ? _channel(row) : null,
    );
  }

  /// The play lines of a live room: the pull URLs of its channel.
  static List<LivePlayLine> playLines(Object? channel, String roomId) {
    if (channel is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final hls = channel['hls_pull_url']?.toString() ?? '';
    final flv = channel['flv_pull_url']?.toString() ?? '';
    if (hls.startsWith('http')) {
      lines.add(LivePlayLine(url: hls, headers: headers, format: StreamFormat.hls, lineId: 'hls'));
    }
    if (flv.startsWith('http')) {
      lines.add(LivePlayLine(url: flv, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
    }
    return lines;
  }

  static Map<String, Object?>? _channel(Map<String, Object?> row) {
    final channel = row['channel'];
    return channel is Map<String, Object?> ? channel : null;
  }

  /// `status.open_time`: epoch milliseconds from 2000 on.
  static DateTime? _startedAt(Object? value) {
    final milliseconds = (value as num?)?.toInt();
    if (milliseconds == null || milliseconds < 946684800000 || milliseconds >= 10000000000000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  /// Passes a full image URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
