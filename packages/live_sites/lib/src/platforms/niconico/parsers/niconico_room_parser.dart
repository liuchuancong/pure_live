import 'dart:convert';

import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_json.dart';

// The value snapshot spells its class name in its constructor; the `.new`
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = 'niconico';

/// A program's broadcast state on its watch page (the `status` string).
enum NiconicoProgramStatus {
  /// `RELEASED`: announced, not started.
  scheduled,

  /// `ON_AIR`.
  onAir,

  /// `ENDED`.
  ended,
}

/// Whether an anonymous viewer may watch a program.
enum NiconicoAccess {
  /// `canWatch`.
  allowed,

  /// `programWatch.condition.needLogin`.
  loginRequired,

  /// `userProgramWatch.isCountryRestrictionTarget`.
  regionRestricted,

  /// Anything else that keeps `canWatch` false (member-only or paid).
  denied,
}

/// What a watch page yields: the program, its room, its state, whether an
/// anonymous viewer may watch and — when on air and allowed — the seat's
/// WebSocket bootstrap. Short-lived (the socket carries a token): never
/// stored as permanent room metadata, it rides the room's runtime handle so
/// playback and comments open a seat without reading the page twice.
final class NiconicoWatch {
  /// Creates the snapshot; [roomId] defaults to the program.
  const NiconicoWatch({
    required this.programId,
    required this.title,
    required this.broadcaster,
    required this.status,
    required this.access,
    this.roomId,
    this.watchCount,
    this.socket,
    this.cover,
    this.avatar,
    this.startedAt,
    this.description,
    this.paid = false,
    this.deniedAs = LiveRestriction.needsLogin,
  });

  /// `lv…`: one broadcast, not its broadcaster.
  final String programId;

  /// The room the page belongs to (`user/<id>`, `ch<n>` or the program).
  final String? roomId;

  /// Program title.
  final String title;

  /// `program.supplier.name`.
  final String broadcaster;

  /// Broadcast state.
  final NiconicoProgramStatus status;

  /// Whether an anonymous viewer may watch.
  final NiconicoAccess access;

  /// `statistics.watchCount`: cumulative visits, not concurrent viewers.
  final int? watchCount;

  /// The seat's WebSocket with `frontend_id`, only when on air and allowed.
  final Uri? socket;

  /// The live screenshot, else the program thumbnail.
  final String? cover;

  /// The broadcaster's icon.
  final String? avatar;

  /// `program.beginTime`, when valid.
  final DateTime? startedAt;

  /// `program.description` as plain text, or null.
  final String? description;

  /// Whether the program is paid (a ticket or a channel membership).
  final bool paid;

  /// What keeps a [NiconicoAccess.denied] program from an anonymous viewer.
  final LiveRestriction deniedAs;

  /// The room's id: the broadcaster's page when known, else the program.
  String get room => roomId ?? programId;

  /// Whether the program is on air.
  bool get isOnAir => status == NiconicoProgramStatus.onAir;

  /// Whether an anonymous viewer may watch its stream.
  bool get isPlayable => isOnAir && access == NiconicoAccess.allowed;

  /// The broadcast status of the room.
  LiveStatus get liveStatus => isOnAir ? LiveStatus.live : LiveStatus.offline;

  /// The restriction of a program on air: none when an anonymous viewer may
  /// watch (a paid program's free part too), else why not; null when not on
  /// air.
  LiveRestriction? get restriction => !isOnAir
      ? null
      : switch (access) {
          NiconicoAccess.allowed => LiveRestriction.none,
          NiconicoAccess.regionRestricted => LiveRestriction.regionBlocked,
          NiconicoAccess.loginRequired => LiveRestriction.needsLogin,
          NiconicoAccess.denied => deniedAs,
        };
}

/// Pure parsing of the niconico watch page and the recent/search lists. Each
/// function takes the response text/bytes and the HTTP status and returns
/// shared models, or throws a [NiconicoFailure].
abstract final class NiconicoRoomParser {
  static final RegExp _scriptTag = RegExp(r'''<script\b((?:[^>"']|"[^"]*"|'[^']*')*)>''', caseSensitive: false);
  static final RegExp _tagAttribute = RegExp(r'''([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''');

  /// The largest watch-page or list body accepted (2 MiB). Niconico's own
  /// pages stay far under it; a body over it is a proxy feeding us something
  /// else, and decoding it risks the isolate rather than informing us.
  static const int responseLimit = 2 * 1024 * 1024;

  static void _limit(String body, String what) {
    // The check runs on both counts: Dart strings are UTF-16 code units, the
    // wire is UTF-8, and a CJK-heavy body can be far bigger as bytes than as
    // characters.
    if (body.length > responseLimit || (body.length * 3 > responseLimit && utf8.encode(body).length > responseLimit)) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, '$what: over ${responseLimit ~/ 1024} KiB');
    }
  }

  /// The watch page of [roomId]: the single `<script id="embedded-data"
  /// data-props="...">` whose attribute is HTML-entity-decoded JSON. The
  /// program a page shows must match [roomId] (a program's `lv…`, a
  /// broadcaster's `user/<id>` or `ch<n>`). Anything else (not exactly one
  /// such script, bad status, non-boolean access flags) is `apiChanged`.
  static NiconicoWatch watch(String body, {required String roomId, int status = 200}) {
    _status(status, 'watch page', notFound: true);
    _limit(body, 'watch page');
    final props = <String>[];
    for (final tag in _scriptTag.allMatches(body)) {
      final attributes = _attributes(tag.group(1)!);
      if (attributes['id'] == 'embedded-data') props.add(attributes['data-props'] ?? '');
    }
    if (props.length != 1) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: ${props.length} embedded-data scripts');
    }
    final decoded = decodeJson(decodeHtmlEntities(props.single));
    final data = jsonObject(decoded);
    if (data == null) {
      throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: embedded-data is not JSON');
    }
    return watchData(data, roomId: roomId);
  }

  /// [watch] from the decoded `embedded-data`.
  static NiconicoWatch watchData(Map<String, dynamic> data, {required String roomId}) {
    final program = jsonObject(data['program']);
    if (program == null) throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: no program');
    final id = program['nicoliveProgramId'];
    final supplier = jsonObject(program['supplier']) ?? const <String, dynamic>{};
    final social = jsonObject(data['socialGroup']);
    final channel = social != null && social['type'] == 'channel' ? social : null;
    final String programId;
    final String room;
    if (NiconicoEndpoints.isProgramId(roomId)) {
      if (id is! String || id != roomId) {
        throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: asked for $roomId, got $id');
      }
      programId = id;
      room = NiconicoEndpoints.roomIdOf(
        programId: id,
        providerType: program['providerType'],
        userId: supplier['supplierType'] == 'user' ? supplier['programProviderId'] : null,
        channelId: channel?['id'],
      );
    } else {
      if (id is! String || !NiconicoEndpoints.isProgramId(id)) {
        throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: program id $id');
      }
      final owner = NiconicoEndpoints.isUserRoomId(roomId) ? 'user/${supplier['programProviderId']}' : channel?['id'];
      if (owner != roomId) {
        throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: asked for $roomId, got $id of $owner');
      }
      programId = id;
      room = roomId;
    }
    final status = switch (program['status']) {
      'RELEASED' => NiconicoProgramStatus.scheduled,
      'ON_AIR' => NiconicoProgramStatus.onAir,
      'ENDED' => NiconicoProgramStatus.ended,
      final Object? other => throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: status $other'),
    };
    final condition = jsonObject(jsonObject(data['programWatch'])?['condition']) ?? const <String, dynamic>{};
    final needsLogin = _boolean(condition['needLogin']);
    final user = jsonObject(data['userProgramWatch']) ?? const <String, dynamic>{};
    final countryRestricted = _boolean(user['isCountryRestrictionTarget']);
    final canWatch = _boolean(user['canWatch']);
    final access = countryRestricted
        ? NiconicoAccess.regionRestricted
        : needsLogin
        ? NiconicoAccess.loginRequired
        : canWatch
        ? NiconicoAccess.allowed
        : NiconicoAccess.denied;
    final count = jsonInt(jsonObject(program['statistics'])?['watchCount']);
    Uri? socket;
    if (status == NiconicoProgramStatus.onAir && access == NiconicoAccess.allowed) {
      final site = jsonObject(data['site']);
      socket = _socket(jsonObject(site?['relive'])?['webSocketUrl'], site?['frontendId']);
    }
    final icons = supplier['icons'];
    final payment = condition['payment'];
    final paid = (payment is String && payment.isNotEmpty) || program['payment'] is Map;
    return NiconicoWatch(
      programId: programId,
      roomId: room,
      title: jsonString(program['title']) ?? '',
      broadcaster: jsonString(supplier['name']) ?? '',
      status: status,
      access: access,
      watchCount: count,
      socket: socket,
      cover: _screenshot(program['screenshot']) ?? _thumbnail(program['thumbnail']),
      avatar:
          (icons is Map ? publicImage(icons['uri150x150']) : null) ??
          (NiconicoEndpoints.isChannelRoomId(room) ? publicImage(channel?['thumbnailImageUrl']) : null),
      startedAt: startedAtSeconds(program['beginTime']),
      description: plainText(program['description']),
      paid: paid,
      deniedAs: program['isPrivate'] == true
          ? LiveRestriction.private
          : paid
          ? LiveRestriction.paid
          : program['isFollowerOnly'] == true
          ? LiveRestriction.subscribersOnly
          : LiveRestriction.needsLogin,
    );
  }

  /// The watch snapshot as a [LiveRoom] (its identity the room, its runtime
  /// handles the snapshot for the seat).
  static LiveRoom room(NiconicoWatch watch) {
    final live = watch.isOnAir;
    return LiveRoom.normalized(
      platform: _site,
      roomId: watch.room,
      content: RoomContent(title: watch.title, coverUrl: watch.cover ?? '', introduction: watch.description),
      anchor: watch.broadcaster.isEmpty
          ? null
          : LiveAnchor.normalized(
              platform: _site,
              anchorId: watch.programId,
              name: watch.broadcaster,
              avatarUrl: watch.avatar,
            ),
      audience: RoomAudience(totalViewers: watch.watchCount, primaryMetric: LiveAudienceMetricType.totalViewers),
      broadcast: RoomBroadcast(
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        startedAt: live ? watch.startedAt : null,
        restriction: watch.restriction,
      ),
      links: RoomLinks(webUrl: NiconicoEndpoints.watchPage(watch.room).toString()),
      runtime: RoomRuntime(streamHandle: watch, danmakuHandle: watch),
    );
  }

  // Lists ---------------------------------------------------------------------

  /// `recent/v1/programs` ([search] false) or `search/v1/programs` ([search]
  /// true): a page of on-air programs. `meta.statusCode == 200` and
  /// `meta.errorCode == 'OK'` gate the page (else apiChanged). A row that is
  /// not on air / of a known provider / with a title, name and self link is
  /// dropped; the page fails only when every row is malformed. A card is a
  /// broadcaster once per page.
  static ({List<LiveRoom> rooms, bool hasMore}) listPage(
    String body, {
    required int page,
    required bool search,
    int status = 200,
  }) {
    final what = search ? 'search' : 'recent';
    _status(status, what);
    _limit(body, what);
    final root = jsonObject(decodeJson(body));
    if (root == null) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, '$what: not an object (${jsonSnippet(body)})');
    }
    final meta = jsonObject(root['meta']);
    if (meta == null || jsonInt(meta['statusCode']) != 200 || meta['errorCode'] != 'OK') {
      throw NiconicoFailure(NiconicoFailureKind.network, '$what: meta ${meta?['statusCode']} ${meta?['errorCode']}');
    }
    final data = search ? (jsonObject(root['data']) ?? meta) : meta;
    final total = jsonInt(data['totalCount']);
    final rows = search ? data['programs'] : root['data'];
    final size = search ? NiconicoEndpoints.searchPageSize : NiconicoEndpoints.recentPageSize;
    if (rows is! List || rows.length > size || total == null || total < rows.length) {
      throw NiconicoFailure(
        NiconicoFailureKind.apiChanged,
        '$what: ${rows is List ? rows.length : 'no'} rows, totalCount $total',
      );
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    NiconicoFailure? malformed;
    for (final raw in rows) {
      final row = jsonObject(raw);
      if (row == null) continue;
      final LiveRoom room;
      try {
        room = listRoom(row, search: search);
      } on NiconicoFailure catch (failure) {
        malformed ??= failure;
        continue;
      }
      if (seen.add(room.roomId)) rooms.add(room);
    }
    if (rooms.isEmpty && malformed != null) throw malformed;
    return (rooms: rooms, hasMore: total > page * size);
  }

  /// One list row as a [LiveRoom]. A row must be a program (`lv…`), on air
  /// (`liveCycle`/`status` `ON_AIR`), of a known provider type, with a title
  /// and a self link; anything else throws [NiconicoFailure] `apiChanged` so
  /// [listPage] can drop it. [search] picks the search row shape
  /// (`nicoliveProgramId`/`status`/`supplier`/`beginTime`) over the recent row
  /// shape (`id`/`liveCycle`/`programProvider`/`beginAt`).
  static LiveRoom listRoom(Map<String, dynamic> row, {required bool search}) {
    final id = jsonString(row[search ? 'nicoliveProgramId' : 'id'])?.trim() ?? '';
    if (!NiconicoEndpoints.isProgramId(id)) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'list: program id $id');
    }
    final link = jsonString(row['watchPageUrl'])?.trim() ?? '';
    if (programIdFromUrl(link) != id && link != id) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'list: $id links to $link');
    }
    final state = search ? row['status'] : row['liveCycle'];
    if (state != 'ON_AIR') throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'list: $id is $state');
    final providerType = row['providerType'];
    if (!const {'community', 'channel', 'official'}.contains(providerType)) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'list: $id provider type $providerType');
    }
    final provider = jsonObject(row[search ? 'supplier' : 'programProvider']);
    final social = jsonObject(row['socialGroup']);
    final name = provider?['name'] ?? social?['name'];
    final icons = provider?['icons'];
    final icon = search ? (icons is Map ? icons['uri150x150'] : null) : provider?['icon'];
    final count = jsonInt(jsonObject(row['statistics'])?['watchCount']);
    final roomId = NiconicoEndpoints.roomIdOf(
      programId: id,
      providerType: providerType,
      userId: provider?[search ? 'programProviderId' : 'id'],
      channelId: social?['id'],
    );
    final title = jsonString(row['title'])?.trim() ?? '';
    if (title.isEmpty) throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'list: title missing');
    return LiveRoom.normalized(
      platform: _site,
      roomId: roomId,
      content: RoomContent(
        title: title,
        coverUrl: publicImage(row['flippedListingThumbnail']) ?? publicImage(row['listingThumbnail']) ?? '',
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: id,
        name: jsonString(name) ?? '',
        avatarUrl: publicImage(icon) ?? publicImage(social?['thumbnailImageUrl']),
      ),
      area: const LiveArea(platform: _site, areaId: NiconicoEndpoints.areaId, areaName: 'niconico'),
      audience: RoomAudience(totalViewers: count, primaryMetric: LiveAudienceMetricType.totalViewers),
      broadcast: RoomBroadcast(
        liveStatus: LiveStatus.live,
        startedAt: search ? startedAtSeconds(row['beginTime']) : startedAtMilliseconds(row['beginAt']),
        restriction: listRestriction(row, search: search),
      ),
      links: RoomLinks(webUrl: NiconicoEndpoints.watchPage(roomId).toString()),
    );
  }

  /// A list row's restriction: a paid program [LiveRestriction.paid], a
  /// followers-only one [LiveRestriction.subscribersOnly], both false none;
  /// without the flags null.
  static LiveRestriction? listRestriction(Map<String, dynamic> row, {required bool search}) {
    final paid = row[search ? 'payment' : 'isPayProgram'];
    final followers = row['isFollowerOnly'];
    if (paid == true || paid is Map) return LiveRestriction.paid;
    if (followers == true) return LiveRestriction.subscribersOnly;
    return paid == false && followers == false ? LiveRestriction.none : null;
  }

  /// A start from epoch milliseconds (the recent list's `beginAt`).
  static DateTime? startedAtMilliseconds(Object? value) => switch (value) {
    final int milliseconds when milliseconds >= 1000000000000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };

  /// A start from epoch seconds (search's and the watch page's `beginTime`).
  static DateTime? startedAtSeconds(Object? value) => switch (value) {
    final int seconds when seconds >= 1000000000 && seconds < 10000000000 => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    _ => null,
  };

  /// The search page's rooms and whether [page] of them is not the last one:
  /// `totalCount` says how many programs match, so the caller can stop paging
  /// without reading an empty page.
  static ({List<LiveSearchResult> items, bool hasMore}) searchRooms(String body, {int status = 200, int page = 1}) {
    final page1 = listPage(body, page: page, search: true, status: status);
    return (items: [for (final room in page1.rooms) LiveSearchResult.room(room)], hasMore: page1.hasMore);
  }

  // Links ---------------------------------------------------------------------

  static const String _query = r'(?:\?[^#\s]*)?(?:#\S*)?$';
  static final RegExp _programLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/(lv[1-9][0-9]{0,17})' + _query,
  );
  static final RegExp _shortLink = RegExp(r'^https?://nico\.ms/(lv[1-9][0-9]{0,17})' + _query);
  static final RegExp _broadcasterLink = RegExp(
    r'^https?://(?:live\.nicovideo\.jp|sp\.live\.nicovideo\.jp)/watch/(user/[1-9][0-9]{0,18}|ch[1-9][0-9]{0,18})' +
        _query,
  );
  static final RegExp _userPage = RegExp(
    r'^https?://(?:www\.|sp\.)?nicovideo\.jp/user/([1-9][0-9]{0,18})(?:/[a-z_]+)?' + _query,
  );
  static final RegExp _channelPage = RegExp(
    r'^https?://ch\.nicovideo\.jp/(?:channel/)?(ch[1-9][0-9]{0,18})(?:/[a-z_]+)?' + _query,
  );

  /// The program of a program link: `live.nicovideo.jp/watch/lv…`, the old
  /// mobile site `sp.live.nicovideo.jp/watch/lv…` and the share link
  /// `nico.ms/lv…`, over http(s), with an optional query and fragment.
  static String? programIdFromUrl(String url) {
    final value = url.trim();
    if (value.length > 2048) return null;
    return (_programLink.firstMatch(value) ?? _shortLink.firstMatch(value))?.group(1);
  }

  /// The broadcaster of a broadcaster link: `…/watch/user/<id>` and
  /// `…/watch/ch<n>`, a user's page `www.nicovideo.jp/user/<id>` and a
  /// channel's page `ch.nicovideo.jp/ch<n>` or `…/channel/ch<n>`.
  static String? broadcasterRoomIdFromUrl(String url) {
    final value = url.trim();
    if (value.length > 2048) return null;
    final user = _userPage.firstMatch(value)?.group(1);
    if (user != null) return 'user/$user';
    return (_broadcasterLink.firstMatch(value) ?? _channelPage.firstMatch(value))?.group(1);
  }

  // Helpers -------------------------------------------------------------------

  static Uri? _socket(Object? value, Object? frontend) {
    final raw = value is String ? value : null;
    if (raw == null || frontend is! int || frontend <= 0 || frontend > 9999) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !isSeatSocket(uri)) return null;
    return uri.replace(queryParameters: {...uri.queryParameters, 'frontend_id': '$frontend'});
  }

  /// Whether [uri] is a seat WebSocket: `wss://a.live2.nicovideo.jp`
  /// `/[unama/]wsapi/v2/watch/<n>` without port, credentials or fragment.
  static bool isSeatSocket(Uri uri) =>
      uri.isScheme('wss') &&
      uri.host == NiconicoEndpoints.seatHost &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasFragment &&
      RegExp(r'^/(?:unama/)?wsapi/v2/watch/[1-9][0-9]*$').hasMatch(uri.path);

  static String? _screenshot(Object? value) {
    if (value is! Map || value['urlSet'] is! Map) return null;
    final urls = value['urlSet'] as Map;
    return publicImage(urls['middle']) ?? publicImage(urls['large']) ?? publicImage(urls['small']);
  }

  static String? _thumbnail(Object? value) {
    if (value is! Map) return null;
    final huge = value['huge'];
    return publicImage(huge is Map ? huge['s640x360'] : null) ??
        publicImage(value['large']) ??
        publicImage(value['small']);
  }

  /// [value] when it is an https image link on `*.nimg.jp` or
  /// `*.nicovideo.jp`, written without port, credentials or fragment; else
  /// null (artwork is optional, so a bad link drops the picture, not the
  /// room).
  static String? publicImage(Object? value) {
    if (value is! String || value.length > 8192) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isScheme('https') || uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) {
      return null;
    }
    if (!(uri.host.endsWith('.nimg.jp') || uri.host.endsWith('.nicovideo.jp'))) return null;
    final base = 'https://${uri.host}';
    if (value != base && !value.startsWith('$base/') && !value.startsWith('$base?')) return null;
    return value;
  }

  static final RegExp _lineBreak = RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false);
  static final RegExp _tag = RegExp('<[^>]*>');

  /// A program's `description` as plain text: `<br>` and block ends are the
  /// line breaks, other tags dropped keeping their text, entities decoded,
  /// lines trimmed, runs of blank lines kept to one; null when empty.
  static String? plainText(Object? value) {
    if (value is! String) return null;
    final source = value.replaceAll(RegExp(r'\r\n?'), '\n');
    final layout = _lineBreak.hasMatch(source) ? source.replaceAll('\n', ' ') : source;
    final lines = decodeHtmlEntities(layout.replaceAll(_lineBreak, '\n').replaceAll(_tag, ''))
        .split('\n')
        .map((line) => line.trim());
    final text = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, String> _attributes(String text) => {
    for (final match in _tagAttribute.allMatches(text))
      match.group(1)!.toLowerCase(): match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
  };

  /// 401/403/406 risk control, 404 not-found for a watch page (else
  /// apiChanged), 429 rate limited, anything else but 200 network.
  static void _status(int status, String what, {bool notFound = false}) {
    switch (status) {
      case 200:
        return;
      case 401 || 403 || 406:
        throw NiconicoFailure(NiconicoFailureKind.riskControl, '$what: HTTP $status');
      case 404:
        throw NiconicoFailure(
          notFound ? NiconicoFailureKind.notFound : NiconicoFailureKind.apiChanged,
          '$what: HTTP 404',
        );
      case 429:
        throw NiconicoFailure(NiconicoFailureKind.rateLimited, '$what: HTTP $status');
    }
    throw NiconicoFailure(NiconicoFailureKind.network, '$what: HTTP $status');
  }

  static bool _boolean(Object? value) {
    if (value is bool) return value;
    throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'watch page: access flag is not a boolean');
  }
}
