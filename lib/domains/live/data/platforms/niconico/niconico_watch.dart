import 'dart:convert';

import 'package:html/parser.dart' as html;

enum NiconicoFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  notLive,
  sessionClosed,
  sessionError,
  cleanup,
}

class NiconicoException implements Exception {
  const NiconicoException(this.kind);
  final NiconicoFailure kind;
  @override
  String toString() => 'Niconico ${kind.name}';
}

enum NiconicoStatus { scheduled, onAir, ended }

enum NiconicoAccess { allowed, loginRequired, regionRestricted, denied }

/// A program-specific watch-page snapshot, not a persistent broadcaster ID.
/// The websocket is a short-lived bootstrap, not a playable media URL. Playback
/// needs an owned seat/heartbeat session and path-scoped cookies from that session.
class NiconicoWatch {
  const NiconicoWatch({
    required this.programId,
    required this.title,
    required this.broadcaster,
    required this.status,
    required this.access,
    required this.reportedWatchCount,
    required this.webSocketUri,
    this.cover,
    this.avatar,
  });

  static const responseLimit = 2 * 1024 * 1024;
  final String programId;
  final String title;
  final String broadcaster;
  final NiconicoStatus status;
  final NiconicoAccess access;
  // Cumulative platform watch count, not concurrent viewers.
  final int? reportedWatchCount;
  final Uri? webSocketUri;
  final String? cover;
  final String? avatar;

  static String validateProgramId(String id) {
    if (!RegExp(r'^lv[1-9][0-9]{0,17}$').hasMatch(id)) {
      throw const NiconicoException(NiconicoFailure.identity);
    }
    return id;
  }

  static String parseInput(String input) {
    if (input.length > 2048) throw const NiconicoException(NiconicoFailure.identity);
    final value = input.trim();
    if (value.startsWith('lv')) return validateProgramId(value);
    // Check raw spelling before URI normalization: dot segments/encoded paths,
    // alternate hosts, credentials and ports are not observed watch contracts.
    final match = RegExp(r'^https://live\.nicovideo\.jp/watch/(lv[1-9][0-9]{0,17})(?:\?[^#\s]*)?(?:#[^\s]*)?$')
        .firstMatch(value);
    if (match == null) throw const NiconicoException(NiconicoFailure.identity);
    return validateProgramId(match.group(1)!);
  }

  static NiconicoWatch parsePage(String body, {required String programId}) {
    validateProgramId(programId);
    if (body.length > responseLimit || utf8.encode(body).length > responseLimit) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    final nodes = html.parse(body).querySelectorAll('script#embedded-data');
    if (nodes.length != 1) throw const NiconicoException(NiconicoFailure.schema);
    final encoded = nodes.single.attributes['data-props'];
    if (encoded == null) throw const NiconicoException(NiconicoFailure.schema);
    try {
      return parseData(_object(jsonDecode(encoded)), programId: programId);
    } on FormatException {
      throw const NiconicoException(NiconicoFailure.schema);
    }
  }

  static NiconicoWatch parseData(Map<String, dynamic> data, {required String programId}) {
    validateProgramId(programId);
    final program = _object(data['program']);
    if (_text(program['nicoliveProgramId']) != programId) {
      throw const NiconicoException(NiconicoFailure.identity);
    }
    final status = switch (program['status']) {
      'RELEASED' => NiconicoStatus.scheduled,
      'ON_AIR' => NiconicoStatus.onAir,
      'ENDED' => NiconicoStatus.ended,
      _ => throw const NiconicoException(NiconicoFailure.schema),
    };
    final needsLogin = _boolean(_object(_object(data['programWatch'])['condition'])['needLogin']);
    final userWatch = _object(data['userProgramWatch']);
    final countryRestricted = _boolean(userWatch['isCountryRestrictionTarget']);
    final canWatch = _boolean(userWatch['canWatch']);
    final access = countryRestricted
        ? NiconicoAccess.regionRestricted
        : needsLogin
        ? NiconicoAccess.loginRequired
        : canWatch
        ? NiconicoAccess.allowed
        : NiconicoAccess.denied;
    final count = _object(program['statistics'])['watchCount'];
    if (count != null && (count is! int || count < 0 || count > 9007199254740991)) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    Uri? socket;
    if (status == NiconicoStatus.onAir && access == NiconicoAccess.allowed) {
      final site = _object(data['site']);
      final raw = _text(_object(site['relive'])['webSocketUrl']);
      final frontend = site['frontendId'];
      if (frontend is! int || frontend <= 0 || frontend > 9999) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      final uri = Uri.tryParse(raw);
      if (raw.length > 8192 ||
          uri == null ||
          uri.scheme != 'wss' ||
          uri.host != 'a.live2.nicovideo.jp' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.hasFragment ||
          !RegExp(r'^/(?:unama/)?wsapi/v2/watch/[1-9][0-9]*$').hasMatch(uri.path) ||
          !raw.startsWith('wss://a.live2.nicovideo.jp${uri.path}?') ||
          uri.queryParametersAll.values.any((values) => values.length != 1)) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      socket = uri.replace(queryParameters: {...uri.queryParameters, 'frontend_id': '$frontend'});
    }
    return NiconicoWatch(
      programId: programId,
      title: _text(program['title']),
      broadcaster: _text(_object(program['supplier'])['name']),
      status: status,
      access: access,
      reportedWatchCount: count as int?,
      webSocketUri: socket,
      cover: _screenshot(program['screenshot']) ?? _cover(program['thumbnail']),
      avatar: _avatar(_object(program['supplier'])['icons']),
    );
  }

  static String? _screenshot(Object? value) {
    if (value is! Map || value['urlSet'] is! Map) return null;
    final urls = value['urlSet'] as Map;
    return publicImage(urls['middle']) ?? publicImage(urls['large']) ?? publicImage(urls['small']);
  }

  static String? _avatar(Object? value) => value is Map ? publicImage(value['uri150x150']) : null;

  static String? _cover(Object? value) {
    if (value is! Map) return null;
    final huge = value['huge'];
    return publicImage(huge is Map ? huge['s640x360'] : null) ??
        publicImage(value['large']) ??
        publicImage(value['small']);
  }

  // Optional artwork is presentation-only. Drop malformed or unrelated links
  // without discarding otherwise valid live/access metadata.
  static String? publicImage(Object? value) {
    if (value is! String || value.length > 8192) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) return null;
    if (!(uri.host.endsWith('.nimg.jp') || uri.host.endsWith('.nicovideo.jp'))) return null;
    // Uri normalizes an explicit default :443 port away; check raw authority.
    final origin = 'https://${uri.host}';
    if (value != origin && !value.startsWith('$origin/') && !value.startsWith('$origin?')) return null;
    return value;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const NiconicoException(NiconicoFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String) throw const NiconicoException(NiconicoFailure.schema);
    return value;
  }

  static bool _boolean(Object? value) {
    if (value is! bool) throw const NiconicoException(NiconicoFailure.schema);
    return value;
  }
}
