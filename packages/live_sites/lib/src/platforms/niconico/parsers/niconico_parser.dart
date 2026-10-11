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

  /// The area type of the seven tabs.
  static const String areaType = 'recent';

  /// The seven tabs, in the site's own order; `common` is the
  /// recommendations rather than a subject.
  static const Map<String, String> tabNames = {
    'common': '综合',
    'try': '创作与挑战',
    'live': '游戏',
    'req': '视频介绍',
    'face': '露脸直播',
    'totu': '连麦互动',
    'vtuber': 'VTuber',
  };

  /// Rows one page of the recent programs carries.
  static const int recentPageSize = 70;

  /// The path of the recent-programs page.
  static const String directoryPath = '/front/api/pages/recent/v1/programs';

  /// The catalogue: the seven constant tabs, so no request is spent finding
  /// them out.
  static List<LiveArea> areas() => [
    for (final (index, entry) in tabNames.entries.indexed) LiveArea(id: entry.key, name: entry.value, sort: index),
  ];

  /// Whether [areaId] names one of the tabs.
  static bool isTab(String areaId) => tabNames.containsKey(areaId.trim());

  /// The URL of tab [tab]'s page [page] (the API offsets pages by count, and
  /// one page is [recentPageSize] rows).
  static Uri directoryUrl({required String tab, required int page}) =>
      Uri.https('live.nicovideo.jp', directoryPath, {'tab': tab, 'offset': '${page - 1}', 'sortOrder': 'recentDesc'});

  /// A `recent/v1/programs` page: the on-air programs of [tab], each
  /// broadcaster once, and whether the site has another page.
  ///
  /// The service answers under `meta`: a status other than 200 or an
  /// `errorCode` other than `OK` is the service failing rather than a page
  /// without rooms, and is reported as a changed endpoint because that is
  /// what a caller can act on. `totalCount` must be a count of at least the
  /// rows, and the rows a list of at most [recentPageSize]. A row that
  /// cannot be read costs itself, while a page whose every row cannot be
  /// read is a changed endpoint.
  static LivePage<LiveRoom> directoryPage(String body, {required String tab, required int page, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('niconico recent $tab: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('niconico recent $tab: body is not JSON');
    }
    final root = decoded is Map<String, Object?> ? decoded : null;
    final meta = SiteJson.object(root?['meta']);
    if (SiteCounts.integer(meta['statusCode']) != 200 || SiteText.trimmed(meta['errorCode']) != 'OK') {
      throw SiteApiChangedError('niconico recent $tab: meta ${meta['statusCode']} ${meta['errorCode']}');
    }
    final total = SiteCounts.integer(meta['totalCount']);
    final rows = SiteJson.list(root?['data']);
    if (total == null || total < rows.length || rows.length > recentPageSize) {
      throw SiteApiChangedError('niconico recent $tab: ${rows.length} rows, totalCount $total');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    var unreadable = 0;
    for (final row in rows) {
      final room = listRoom(SiteJson.object(row));
      if (room == null) {
        unreadable++;
        continue;
      }
      if (seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    if (rooms.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('niconico recent $tab: every one of $unreadable rows is unreadable');
    }
    final hasMore = total > page * recentPageSize;
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null, totalCount: total);
  }

  /// One `recent` row as a room, or null when the row is not an on-air
  /// program of a known kind.
  ///
  /// The room is the broadcaster rather than the program when the site names
  /// one ([roomIdOf]), so a program that ends does not orphan a followed
  /// broadcaster. A row is kept only when it is on air (`liveCycle`) and
  /// links to itself; its title, provider name and pictures come from the
  /// answer, its viewers from `statistics.watchCount` (the visit count the
  /// site publishes), and its restriction from `isPayProgram` and
  /// `isFollowerOnly` — a paid or followers-only program is listed, because
  /// the site lists it, and the watch page decides playback.
  static LiveRoom? listRoom(Map<String, Object?> row) {
    final programId = SiteText.trimmed(row['id']);
    if (!isProgramId(programId)) {
      return null;
    }
    if (!_isWatchLink(SiteText.trimmed(row['watchPageUrl']), programId)) {
      return null;
    }
    if (SiteText.trimmed(row['liveCycle']) != 'ON_AIR') {
      return null;
    }
    final providerType = SiteText.trimmed(row['providerType']);
    if (!const {'community', 'channel', 'official'}.contains(providerType)) {
      return null;
    }
    final provider = SiteJson.object(row['programProvider']);
    final social = SiteJson.object(row['socialGroup']);
    final started = SiteCounts.integer(row['beginAt']);
    return LiveRoom(
      platform: SiteIds.niconico,
      roomId: roomIdOf(
        programId: programId,
        providerType: providerType,
        userId: provider['id'],
        channelId: social['id'],
      ),
      title: SiteText.title(SiteText.text(row['title'])),
      nick: SiteText.title(SiteText.text(provider['name'] ?? social['name'])),
      avatar: publicImage(provider['icon']) ?? publicImage(social['thumbnailUrl']),
      cover: publicImage(row['flippedListingThumbnail']) ?? publicImage(row['listingThumbnail']),
      status: LiveStatus.live,
      watching: SiteCounts.integer(SiteJson.object(row['statistics'])['watchCount']),
      restriction: listRestriction(row),
      startedAt: started != null && started >= 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(started, isUtc: true)
          : null,
    );
  }

  /// Whether [link] is the watch page of [programId].
  ///
  /// The site writes a `ref` on every card's link, so a query — and a
  /// fragment with it — is allowed; anything else, including another
  /// program's page, is not.
  static bool _isWatchLink(String link, String programId) {
    if (link == programId) {
      return true;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    return segments.length == 2 && segments[0] == 'watch' && segments[1] == programId;
  }

  /// The restriction a list row states: a paid program is `paid`, a
  /// followers-only one `subscribersOnly`, both flags false none, and a row
  /// without the flags says nothing (null).
  static LiveRestriction? listRestriction(Map<String, Object?> row) {
    final paid = row['isPayProgram'];
    final followers = row['isFollowerOnly'];
    if (paid == true || paid is Map) {
      return LiveRestriction.paid;
    }
    if (followers == true) {
      return LiveRestriction.subscribersOnly;
    }
    return paid == false && followers == false ? LiveRestriction.none : null;
  }

  /// The room id of a program: the broadcaster's when the provider names one
  /// — a community or user program becomes `user/<id>`, a channel program
  /// its `ch<id>` — else the program itself.
  static String roomIdOf({required String programId, Object? providerType, Object? userId, Object? channelId}) {
    final user = userId is int ? '$userId' : (userId is String ? userId : '');
    if ((providerType == 'community' || providerType == 'user') && RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(user)) {
      return 'user/$user';
    }
    if (providerType == 'channel' && channelId is String && isChannelRoomId(channelId)) {
      return channelId;
    }
    return programId;
  }

  /// A public image URL of the site's own hosts, else null.
  ///
  /// The list answers carry URLs this client must not load blindly: an image
  /// is kept only when it is https, on a `*.nimg.jp` or `*.nicovideo.jp`
  /// host, without a port, user info or fragment, and written without an
  /// explicit `:443` (which [Uri] drops, so the check would reject it).
  static String? publicImage(Object? value) {
    if (value is! String || value.length > 8192) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isScheme('https') || uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) {
      return null;
    }
    if (!(uri.host.endsWith('.nimg.jp') || uri.host.endsWith('.nicovideo.jp'))) {
      return null;
    }
    final base = 'https://${uri.host}';
    return value != base && !value.startsWith('$base/') && !value.startsWith('$base?') ? null : value;
  }

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
