import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Huya room page: the room state lives in a
/// `window.TT_ROOM_DATA = {…}` script blob and the stream table in
/// `window.HYPlayerConfig = {…}`.
abstract final class HuyaParser {
  static final RegExp _roomData = RegExp(r'window\.TT_ROOM_DATA\s*=\s*(\{[^;]*?\});', dotAll: true);

  static final RegExp _playerConfig = RegExp(r'window\.HYPlayerConfig\s*=\s*(\{[^;]*?\});', dotAll: true);

  static final RegExp _htmlPage = RegExp(r'^\s*<!(?:DOCTYPE|html)', caseSensitive: false);

  static final RegExp _scriptEscape = RegExp('</?script[^>]*>');

  /// Whether the body is an HTML page at all (offline rooms still return
  /// the page; a non-HTML body means the flow changed).
  static bool looksLikeHtml(String body) => _htmlPage.hasMatch(body.trimLeft());

  /// Extracts the room snapshot from the page. Throws "not found" when
  /// the TT_ROOM_DATA blob is absent (unknown room ids lead to a 404
  /// page without the blob).
  static LiveRoom roomDetail(String html, {required String requestedId}) {
    if (!looksLikeHtml(html)) {
      throw SiteApiChangedError('huya/$requestedId: body is not HTML');
    }
    final blob = _roomData.firstMatch(html)?.group(1);
    if (blob == null) {
      throw SiteNotFoundError('huya/$requestedId: no TT_ROOM_DATA on the page');
    }
    final data = _decode(blob);
    final introduction = data['introduction']?.toString() ?? '';
    final state = (data['state'] as num?)?.toInt() ?? 0;
    final isReplay = data['isReplay']?.toString() == '1';
    return LiveRoom(
      platform: SiteIds.huya,
      roomId: requestedId,
      title: introduction,
      nick: data['nick']?.toString() ?? '',
      avatar: data['avatar180']?.toString(),
      cover: data['screenshot']?.toString(),
      areaName: data['gameFullName']?.toString(),
      watching: (data['gg_total_count'] as num?)?.toInt(),
      status: isReplay
          ? LiveStatus.replay
          : state == 2
          ? LiveStatus.live
          : state == 3
          ? LiveStatus.carousel
          : LiveStatus.offline,
    );
  }

  /// Extracts the playable lines from `HYPlayerConfig.streamBase`:
  /// one entry per (cdn, rate) combination.
  static List<LivePlayLine> playLines(String html) {
    final blob = _playerConfig.firstMatch(html)?.group(1);
    if (blob == null) {
      throw const SiteApiChangedError('huya: no HYPlayerConfig on the page');
    }
    final config = _decode(blob);
    final base = config['streamBase'];
    final data = base is Map<String, Object?> ? base['data'] : null;
    final list = data is List && data.isNotEmpty ? data.first : null;
    final entries = list is Map<String, Object?> ? list['gameStreamInfoList'] : null;
    final lines = <LivePlayLine>[];
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map<String, Object?>) {
          continue;
        }
        final url = _url(entry);
        if (url == null) {
          continue;
        }
        lines.add(
          LivePlayLine(
            url: url,
            headers: const {
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
              'referer': 'https://www.huya.com/',
            },
            format: (url.contains('.m3u8')) ? StreamFormat.hls : StreamFormat.flv,
            codec: entry['sCdnType']?.toString() == 'AL' ? 'hevc' : 'avc',
            lineId: entry['sCdnType']?.toString(),
          ),
        );
      }
    }
    return lines;
  }

  /// The quality levels present in the stream table.
  static List<LivePlayQuality> playQualities(String html) {
    final blob = _playerConfig.firstMatch(html)?.group(1);
    if (blob == null) {
      return const [];
    }
    final config = _decode(blob);
    final base = config['streamBase'];
    final data = base is Map<String, Object?> ? base['data'] : null;
    final list = data is List && data.isNotEmpty ? data.first : null;
    final entries = list is Map<String, Object?> ? list['gameStreamInfoList'] : null;
    final seen = <int, LivePlayQuality>{};
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map<String, Object?>) {
          continue;
        }
        final rate = (entry['iBitRate'] as num?)?.toInt();
        if (rate == null || seen.containsKey(rate)) {
          continue;
        }
        seen[rate] = LivePlayQuality(quality: rate, label: rate == 0 ? '原画' : '${rate}K', sort: seen.length);
      }
    }
    return seen.values.toList();
  }

  static String? _url(Map<String, Object?> entry) {
    final base = entry['sFlvUrl']?.toString() ?? entry['sHlsUrl']?.toString() ?? '';
    final suffix = entry['sFlvUrlSuffix']?.toString() ?? entry['sHlsUrlSuffix']?.toString() ?? '';
    final antiCode = entry['sFlvAntiCode']?.toString() ?? entry['sHlsAntiCode']?.toString() ?? '';
    if (base.isEmpty || suffix.isEmpty) {
      return null;
    }
    return '$base/$suffix?$antiCode';
  }

  static Map<String, Object?> _decode(String blob) {
    final cleaned = blob.replaceAll(_scriptEscape, '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('huya: page config is not an object');
    }
    return decoded;
  }
}
