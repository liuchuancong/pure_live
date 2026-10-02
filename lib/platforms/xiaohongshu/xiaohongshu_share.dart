import 'dart:convert';

import 'package:html/parser.dart' as html;

enum XiaohongshuFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  api,
  schema,
  identity,
  cancelled,
  notLive,
  mediaUnavailable,
}

class XiaohongshuException implements Exception {
  const XiaohongshuException(this.kind);
  final XiaohongshuFailure kind;
  @override
  String toString() => 'Xiaohongshu ${kind.name}';
}

enum XiaohongshuAccess { public, restricted, unknown }

class XiaohongshuStream {
  const XiaohongshuStream({required this.uri, required this.codec, required this.quality, required this.label});
  final Uri uri;
  final String codec;
  final String quality;
  final String label;
  String get protocol => uri.path.endsWith('.m3u8') ? 'hls' : 'flv';
}

/// Public share-page snapshot, not a persistent broadcaster identity or a
/// directory. Ended pages can omit roomId and include an unrelated recommendation.
class XiaohongshuShare {
  const XiaohongshuShare({
    required this.requestedRoomId,
    required this.responseRoomId,
    required this.reportedStatus,
    required this.reportedLive,
    required this.access,
    required this.title,
    required this.nickname,
    required this.cover,
    required this.avatar,
    required this.displayViewers,
    required this.streams,
  });

  final String requestedRoomId;
  final String? responseRoomId;
  final int reportedStatus;
  final bool? reportedLive;
  final XiaohongshuAccess access;
  final String? title;
  final String? nickname;
  final String? cover;
  final String? avatar;
  // Platform display text, not measured concurrent viewers or an integer count.
  final String? displayViewers;
  final List<XiaohongshuStream> streams;

  static const responseLimit = 2 * 1024 * 1024;

  static String validateRoomId(String id) {
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) {
      throw const XiaohongshuException(XiaohongshuFailure.identity);
    }
    return id;
  }

  /// Accept a JSON-shaped hydration assignment with bare undefined placeholders.
  /// Never execute scripts, replace inside strings, or accept other JS syntax.
  /// The caller must bind this body to the requested URL without auto-redirects.
  static XiaohongshuShare parsePage(String page, {required String roomId}) {
    validateRoomId(roomId);
    if (page.length > responseLimit || utf8.encode(page).length > responseLimit) {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
    const marker = 'window.__INITIAL_STATE__=';
    final scripts = html
        .parse(page)
        .querySelectorAll('script')
        .where((s) => s.text.trimLeft().startsWith(marker))
        .toList();
    if (scripts.length != 1) throw const XiaohongshuException(XiaohongshuFailure.schema);
    var source = scripts.single.text.trim().substring(marker.length).trim();
    if (source.endsWith(';')) source = source.substring(0, source.length - 1).trimRight();
    try {
      final root = _object(jsonDecode(_hydrationJson(source)));
      return parseState(_object(root['liveStream']), roomId: roomId);
    } on FormatException {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
  }

  // The current server emits undefined for optional global configuration, even
  // when liveStream itself is JSON. A global String.replaceAll would corrupt
  // titles/URLs containing that word. This scanner only converts bare tokens;
  // jsonDecode still validates the complete result (no comments/functions/etc.).
  static String _hydrationJson(String source) {
    final result = StringBuffer();
    var quoted = false;
    var escaped = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        result.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
      } else if (char == '"') {
        quoted = true;
        result.write(char);
      } else if (source.startsWith('undefined', i)) {
        result.write('null');
        i += 'undefined'.length - 1;
      } else {
        result.write(char);
      }
    }
    return result.toString();
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const XiaohongshuException(XiaohongshuFailure.schema);
    return value;
  }

  static String? _text(Object? value, {int limit = 4096}) {
    if (value == null) return null;
    if (value is! String || value.length > limit) throw const XiaohongshuException(XiaohongshuFailure.schema);
    return value;
  }

  static XiaohongshuShare parseState(Map<String, dynamic> state, {required String roomId}) {
    validateRoomId(roomId);
    // The frontend uses the same page error for network, missing-room and
    // restricted responses. Its generic message does not prove any one cause.
    if (state['pageStatus'] == 'error') throw const XiaohongshuException(XiaohongshuFailure.api);
    if (state['pageStatus'] != 'success') throw const XiaohongshuException(XiaohongshuFailure.schema);
    final data = _object(state['roomData']);
    final room = _object(data['roomInfo']);
    final host = _object(data['hostInfo']);
    final responseId = room['roomId'];
    if (responseId != null && (responseId is! String || responseId != roomId)) {
      throw const XiaohongshuException(XiaohongshuFailure.identity);
    }
    final status = room['status'];
    if (status is! int || status < 0) throw const XiaohongshuException(XiaohongshuFailure.schema);
    final liveStatus = state['liveStatus'];
    // Observed 2 = live and 3 = ended. Future states remain unknown; the
    // frontend's default "success" alone is not positive live evidence.
    final bool? live = switch (status) {
      2 => true,
      3 => false,
      _ => null,
    };
    if ((live == true && liveStatus != 'success') || (live == false && liveStatus != 'end')) {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
    if (live == true && responseId == null) throw const XiaohongshuException(XiaohongshuFailure.identity);

    final monetization = room['monetizeType'];
    final limits = room['joinLimitTypes'];
    if (monetization != null && (monetization is! int || monetization < 0)) {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
    if (limits != null && (limits is! List || limits.length > 16 || limits.any((v) => v is! int || v < 0))) {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
    final access = monetization == null || limits == null
        ? XiaohongshuAccess.unknown
        : monetization != 0 || (limits as List).any((v) => v != 0)
        ? XiaohongshuAccess.restricted
        : XiaohongshuAccess.public;
    // nextRoomInfo, deeplink preload URLs and replayInfo are deliberately not
    // media sources for this room, nor proof that this room is live.
    final streams = live == true && access == XiaohongshuAccess.public
        ? _streams(room['pullConfig'], roomId)
        : <XiaohongshuStream>[];
    return XiaohongshuShare(
      requestedRoomId: roomId,
      responseRoomId: responseId as String?,
      reportedStatus: status,
      reportedLive: live,
      access: access,
      title: _text(room['roomTitle']),
      nickname: _text(host['nickName']),
      cover: _text(room['roomCover']),
      avatar: _text(host['avatar']),
      displayViewers: _text(room['displayViewerCount']),
      streams: List.unmodifiable(streams),
    );
  }

  static List<XiaohongshuStream> _streams(Object? value, String roomId) {
    if (value == null || value == '') return [];
    if (value is! String || value.length > 65536) throw const XiaohongshuException(XiaohongshuFailure.schema);
    late Map<String, dynamic> config;
    try {
      config = _object(jsonDecode(value));
    } on FormatException {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    }
    final result = <XiaohongshuStream>[];
    final identities = <String>{};
    for (final codec in ['h264', 'h265']) {
      final rows = config[codec];
      if (rows == null) continue;
      if (rows is! List || rows.length > 32) throw const XiaohongshuException(XiaohongshuFailure.schema);
      for (final value in rows) {
        final row = _object(value);
        final url = _text(row['master_url']);
        final quality = _text(row['quality_type'], limit: 64);
        final label = _text(row['quality_type_name'], limit: 128);
        if (url == null || quality == null || quality.isEmpty || label == null || label.isEmpty) {
          throw const XiaohongshuException(XiaohongshuFailure.schema);
        }
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            !(uri.host.endsWith('.xhscdn.com') && uri.host != '.xhscdn.com') ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment ||
            uri.port != (uri.scheme == 'https' ? 443 : 80) ||
            !['/live/$roomId.m3u8', '/live/$roomId.flv'].contains(uri.path)) {
          throw const XiaohongshuException(XiaohongshuFailure.schema);
        }
        // Preserve full query, declared scheme, quality and codec. Duplicate
        // aliases of the same source do not create extra selectable streams.
        if (identities.add('$codec|$quality|$uri')) {
          result.add(XiaohongshuStream(uri: uri, codec: codec, quality: quality, label: label));
        }
      }
    }
    return result;
  }
}
