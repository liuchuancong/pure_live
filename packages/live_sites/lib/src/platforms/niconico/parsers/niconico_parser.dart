import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Niconico live watch pages.
abstract final class NiconicoParser {
  /// Web origin.
  static const String origin = 'https://live.nicovideo.jp';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// The watch page URL of [roomId] (a program id, `user/<id>` or
  /// `ch<n>`).
  static String watchUrl(String roomId) => '$origin/watch/$roomId';

  /// Whether [value] is a program id (`lv` + digits).
  static bool isProgramId(String value) => RegExp(r'^lv\d+$').hasMatch(value);

  /// Whether [value] is a user room id (`user/<id>`).
  static bool isUserRoomId(String value) => RegExp(r'^user/\d+$').hasMatch(value);

  /// Whether [value] is a channel room id (`ch<n>`).
  static bool isChannelRoomId(String value) => RegExp(r'^ch\d+$').hasMatch(value);

  static final RegExp _scriptTag = RegExp(r'<script\b([^>]*)>', caseSensitive: false);
  static final RegExp _attribute = RegExp(r'([\w-]+)\s*=\s*"([^"]*)"');

  /// The watch page → the room. The hydration payload is the single
  /// `script#embedded-data` element's `data-props` attribute.
  static ({LiveRoom room, String? socketUrl}) watch(String body, {required String roomId, int status = 200}) {
    if (status == 404) {
      throw const SiteNotFoundError('niconico watch page: HTTP 404');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('niconico watch page: HTTP $status');
    }
    final props = <String>[];
    for (final tag in _scriptTag.allMatches(body)) {
      final attributes = <String, String>{
        for (final match in _attribute.allMatches(tag.group(1)!)) match.group(1)!: match.group(2)!,
      };
      if (attributes['id'] == 'embedded-data') {
        props.add(attributes['data-props'] ?? '');
      }
    }
    if (props.length != 1) {
      throw SiteApiChangedError('niconico watch page: ${props.length} embedded-data scripts');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(_decodeEntities(props.single));
    } on FormatException {
      throw const SiteApiChangedError('niconico watch page: embedded-data is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('niconico watch page: embedded-data is not an object');
    }
    final data = decoded;
    final program = data['program'];
    if (program is! Map<String, Object?>) {
      throw const SiteApiChangedError('niconico watch page: no program');
    }
    final programId = program['nicoliveProgramId']?.toString() ?? '';
    if (!isProgramId(programId)) {
      throw const SiteApiChangedError('niconico watch page: no program id');
    }
    if (isProgramId(roomId) && programId != roomId) {
      throw SiteApiChangedError('niconico watch page: asked $roomId, got $programId');
    }
    final statusText = program['status']?.toString() ?? '';
    final supplier = program['supplier'];
    final supplierMap = supplier is Map<String, Object?> ? supplier : const <String, Object?>{};
    final social = data['socialGroup'];
    final channel = social is Map<String, Object?> && social['type'] == 'channel' ? social : null;
    if (!isProgramId(roomId)) {
      final owner = isUserRoomId(roomId) ? 'user/${supplierMap['programProviderId']}' : channel?['id']?.toString();
      if (owner != roomId) {
        throw SiteApiChangedError('niconico watch page: asked $roomId, got $programId of $owner');
      }
    }
    final condition = _nested(data, ['programWatch', 'condition']);
    final userWatch = data['userProgramWatch'];
    final userWatchMap = userWatch is Map<String, Object?> ? userWatch : const <String, Object?>{};
    final needsLogin = condition['needLogin'] == true;
    final regionRestricted = userWatchMap['isCountryRestrictionTarget'] == true;
    final canWatch = userWatchMap['canWatch'] == true;
    final access = regionRestricted
        ? 'regionRestricted'
        : needsLogin
        ? 'loginRequired'
        : canWatch
        ? 'allowed'
        : 'denied';
    final live = statusText == 'ON_AIR';
    final statistics = program['statistics'];
    final watchCount = (statistics is Map<String, Object?> ? statistics['watchCount'] : null) as num?;
    final icons = supplierMap['icons'];
    final beginMs = (program['beginTime'] as num?)?.toInt();
    String? socketUrl;
    if (live && access == 'allowed') {
      final site = data['site'];
      final relive = site is Map<String, Object?> ? site['relive'] : null;
      socketUrl = relive is Map<String, Object?> ? relive['webSocketUrl']?.toString() : null;
    }
    return (
      room: LiveRoom(
        platform: SiteIds.niconico,
        roomId: roomId,
        title: program['title']?.toString() ?? '',
        nick: supplierMap['name']?.toString() ?? '',
        avatar: _image(_avatarOf(icons, channel, roomId)),
        cover: _image(program['screenshot'] ?? program['thumbnail']),
        watching: watchCount?.toInt(),
        status: live
            ? LiveStatus.live
            : statusText == 'ENDED'
            ? LiveStatus.offline
            : LiveStatus.unknown,
        restriction: regionRestricted
            ? LiveRestriction.regionBlocked
            : needsLogin
            ? LiveRestriction.needsLogin
            : null,
        startedAt: live && beginMs != null && beginMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(beginMs * 1000, isUtc: true)
            : null,
        data: socketUrl,
      ),
      socketUrl: socketUrl,
    );
  }

  /// The avatar: the supplier's 150px icon, else a channel's thumbnail.
  static Object? _avatarOf(Object? icons, Map<String, Object?>? channel, String roomId) {
    if (icons is Map<String, Object?> && icons['uri150x150'] != null) {
      return icons['uri150x150'];
    }
    if (isChannelRoomId(roomId) && channel != null) {
      return channel['thumbnailImageUrl'];
    }
    return null;
  }

  static Map<String, Object?> _nested(Map<String, Object?> data, List<String> path) {
    Object? current = data;
    for (final key in path) {
      current = current is Map<String, Object?> ? current[key] : null;
    }
    return current is Map<String, Object?> ? current : const <String, Object?>{};
  }

  /// Decodes the HTML entities the attribute value carries (`&quot;` and
  /// friends).
  static String _decodeEntities(String text) => text
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
