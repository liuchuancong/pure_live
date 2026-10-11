import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Kuaishou live room page.
abstract final class KuaishouParser {
  /// Browser-like request headers for the room page.
  static const Map<String, String> webHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://live.kuaishou.com/',
  };

  static final RegExp _stateMarker = RegExp(r'window\.__INITIAL_STATE__\s*=\s*');
  static final RegExp _challenge = RegExp('verify|captcha|challenge', caseSensitive: false);

  /// The `window.__INITIAL_STATE__` object of a room page, extracted by
  /// brace matching (a `;` inside a string does not end it). A page
  /// without the state is a verification page (risk control) or an API
  /// change.
  static Map<String, Object?> initialState(String html, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kuaishou room page: HTTP $status');
    }
    final marker = _stateMarker.firstMatch(html);
    if (marker == null) {
      if (_challenge.hasMatch(html)) {
        throw const SiteRiskControlError('kuaishou room page is a verification page');
      }
      throw const SiteApiChangedError('kuaishou room page: no __INITIAL_STATE__');
    }
    final literal = objectLiteral(html, marker.end);
    if (literal == null) {
      throw const SiteApiChangedError('kuaishou room page: state is not a complete object');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(literal);
    } on FormatException {
      throw const SiteApiChangedError('kuaishou room page: state is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('kuaishou room page: state is not an object');
    }
    return decoded;
  }

  /// The balanced `{…}` literal starting at [start] (first `{` at or after
  /// it), string-aware; null when unbalanced.
  static String? objectLiteral(String text, int start) {
    var index = text.indexOf('{', start);
    if (index < 0) {
      return null;
    }
    final begin = index;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (; index < text.length; index++) {
      final char = text[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(begin, index + 1);
        }
      }
    }
    return null;
  }

  /// The `liveroom.playList[0]` item of a state, with its error type
  /// mapped.
  static Map<String, Object?> playItem(Map<String, Object?> state) {
    final liveroom = state['liveroom'];
    final list = liveroom is Map<String, Object?> ? liveroom['playList'] : null;
    final room = list is List && list.isNotEmpty && list.first is Map<String, Object?> ? list.first : null;
    if (room is! Map<String, Object?>) {
      throw const SiteApiChangedError('kuaishou room page: liveroom.playList[0] missing');
    }
    final error = room['errorType'];
    if (error != null) {
      final type = error is Map<String, Object?> ? (error['type'] as num?)?.toInt() : (error as num?)?.toInt();
      if (type == 22) {
        throw const SiteNotFoundError('kuaishou: room not found (errorType 22)');
      }
      throw SiteRiskControlError('kuaishou: errorType $type');
    }
    return room;
  }

  /// The room snapshot from a room page.
  static LiveRoom roomDetail(String html, {required String requestedId, int status = 200}) {
    final room = playItem(initialState(html, status: status));
    final author = room['author'];
    final stream = room['liveStream'];
    final game = room['gameInfo'];
    final authorMap = author is Map<String, Object?> ? author : const <String, Object?>{};
    final streamMap = stream is Map<String, Object?> ? stream : const <String, Object?>{};
    final gameMap = game is Map<String, Object?> ? game : const <String, Object?>{};
    final living = room['isLiving'] == true;
    return LiveRoom(
      platform: SiteIds.kuaishou,
      roomId: requestedId,
      nick: authorMap['name']?.toString() ?? '',
      avatar: authorMap['avatar']?.toString(),
      cover: _cover(streamMap['poster']),
      areaName: gameMap['name']?.toString(),
      status: living ? LiveStatus.live : LiveStatus.offline,
    );
  }

  /// Play lines collected from [room]'s liveStream.playUrls: every object
  /// holding a `url` becomes a line, with its `name`/quality and the codec
  /// of the surrounding key when recognisable.
  static List<LivePlayLine> playLinesFromRoom(Map<String, Object?> room) {
    final stream = room['liveStream'];
    if (stream is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    _collect(stream['playUrls'], null, null, lines, seen);
    return lines;
  }

  static void _collect(Object? node, String? label, String? codec, List<LivePlayLine> lines, Set<String> seen) {
    if (node is List) {
      for (final item in node) {
        _collect(item, label, codec, lines, seen);
      }
      return;
    }
    if (node is! Map<String, Object?>) {
      return;
    }
    final url = node['url']?.toString() ?? '';
    if (url.startsWith('http') && seen.add(url)) {
      lines.add(
        LivePlayLine(
          url: url,
          headers: webHeaders,
          format: url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
          codec: codec,
          lineId: label,
        ),
      );
    }
    for (final entry in node.entries) {
      final childCodec = switch (entry.key) {
        'h264' || 'avc' => 'avc',
        'hevc' || 'h265' => 'hevc',
        _ => codec,
      };
      _collect(entry.value, node['name']?.toString() ?? label, childCodec, lines, seen);
    }
  }

  static String? _cover(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value.startsWith('//') ? 'https:$value' : value;
    }
    if (value is Map<String, Object?>) {
      final url = value['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        return url.startsWith('//') ? 'https:$url' : url;
      }
    }
    return null;
  }
}
