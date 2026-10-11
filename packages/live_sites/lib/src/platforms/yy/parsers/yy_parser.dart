import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the YY web APIs and room pages.
abstract final class YyParser {
  /// Validates a JSON envelope (`code == 0` / `res == 0`) and returns it.
  static Map<String, Object?> checked(String body, {int status = 200, String what = 'response'}) {
    if (status == 404) {
      throw const SiteNotFoundError('yy response: HTTP 404');
    }
    if (status >= 500) {
      throw SiteApiChangedError('yy $what: HTTP $status');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('yy $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('yy $what: body is not JSON');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('yy $what: body is not an object');
    }
    final code = (root['code'] as num?)?.toInt() ?? (root['res'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw SiteApiChangedError('yy $what: code $code ${root['message']?.toString() ?? ''}'.trim());
    }
    return root;
  }

  /// `api/liveInfoDetail/<sid>/<sid>/0` → the live room, or null when the
  /// channel is not streaming (`data` absent).
  static LiveRoom? liveDetail(String body, {required String requestedId, int status = 200}) {
    final root = checked(body, status: status, what: 'liveInfoDetail');
    final data = root['data'];
    if (data == null) {
      return null;
    }
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('yy liveInfoDetail: data is not an object');
    }
    final sid = channel(data['sid']) ?? requestedId;
    final ssid = channel(data['ssid']) ?? sid;
    return LiveRoom(
      platform: SiteIds.yy,
      roomId: requestedId,
      title: data['desc']?.toString() ?? '',
      nick: data['name']?.toString() ?? '',
      avatar: image(data['avatar']),
      cover: image(data['thumb2']) ?? image(data['thumb']),
      areaName: data['biz']?.toString(),
      watching: int.tryParse(data['users']?.toString() ?? ''),
      status: LiveStatus.live,
      data: {'sid': sid, 'ssid': ssid},
    );
  }

  /// The channel number from a value that may be `number_plain` or
  /// prefixed; digits only.
  static String? channel(Object? value) {
    final digits = (value?.toString() ?? '').replaceAll(RegExp('[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  /// The room page of a channel number: `pageInfo = {…}` carrying the
  /// sid/ssid pair (and streamer facts) for channels whose number is not
  /// their sid.
  static ({String sid, String ssid, String? nick, String? title}) roomPage(String html) {
    if (html.contains('yycom_404')) {
      throw const SiteNotFoundError('yy room page is the 404 page');
    }
    final source = RegExp(r'pageInfo\s*=\s*\{[\s\S]*?\};').firstMatch(html)?.group(0);
    if (source == null) {
      throw const SiteApiChangedError('yy room page: no pageInfo');
    }
    String? field(String name) {
      final match = RegExp('\\b$name\\s*:\\s*(?:decodeURIComponent\\()?"([^"]*)"').firstMatch(source);
      if (match == null) {
        return null;
      }
      return match.group(1);
    }

    final sid = channel(field('sid'));
    if (sid == null) {
      throw const SiteApiChangedError('yy room page: no sid');
    }
    return (sid: sid, ssid: channel(field('ssid')) ?? sid, nick: field('nick'), title: field('roomName'));
  }

  /// The offline room snapshot for a channel: identity and state only.
  static LiveRoom offlineRoom(String requestedId, {String? sid, String? ssid}) => LiveRoom(
    platform: SiteIds.yy,
    roomId: requestedId,
    status: LiveStatus.offline,
    data: sid == null ? null : {'sid': sid, 'ssid': ssid ?? sid},
  );

  /// Play lines of a stream-manager answer: every `stream_line_addr`
  /// entry in server order, de-duplicated by URL.
  static List<LivePlayLine> playLines(Map<String, Object?> streams) {
    final avp = streams['avp_info_res'];
    final addresses = avp is Map<String, Object?> ? avp['stream_line_addr'] : null;
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    if (addresses is Map<String, Object?>) {
      for (final value in addresses.values) {
        if (value is! Map<String, Object?>) {
          continue;
        }
        final cdn = value['cdn_info'];
        var url = cdn is Map<String, Object?> ? cdn['url']?.toString() ?? '' : '';
        if (url.startsWith('//')) {
          url = 'https:$url';
        }
        if (!url.startsWith('http') || !seen.add(url)) {
          continue;
        }
        final lineSeq = value['line_seq']?.toString();
        lines.add(LivePlayLine(url: url, format: StreamFormat.flv, lineId: lineSeq == null ? null : 'line-$lineSeq'));
      }
    }
    return lines;
  }

  /// Passes a non-empty image URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
