import 'dart:convert';
import 'dart:math';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the AcFun / Kuaishou-ZT live APIs.
abstract final class AcfunParser {
  /// API request headers shared by the visitor and startPlay calls.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': 'https://live.acfun.cn',
    'referer': 'https://live.acfun.cn/',
  };

  /// Validates a JSON body and returns the root object.
  static Map<String, Object?> root(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('acfun $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('acfun $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('acfun $what: body is not an object');
    }
    return decoded;
  }

  /// `visitor/login` → the session (userId, token, and the `acSecurity` the
  /// danmaku link registers with), or an error on a refused login.
  static ({String userId, String token, String security}) visitor(String body, {int status = 200}) {
    final parsed = root(body, status: status, what: 'visitor/login');
    final result = (parsed['result'] as num?)?.toInt();
    if (result != 0) {
      throw SiteRiskControlError('acfun visitor/login: result $result');
    }
    final userId = parsed['userId']?.toString() ?? '';
    final token = parsed['acfun.api.visitor_st']?.toString() ?? '';
    if (userId.isEmpty || userId == '0' || token.isEmpty) {
      throw const SiteApiChangedError('acfun visitor/login: incomplete session');
    }
    return (userId: userId, token: token, security: parsed['acSecurity']?.toString() ?? '');
  }

  /// A random 16-char device id for the visitor session.
  static String deviceId() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return [for (var i = 0; i < 16; i++) alphabet[random.nextInt(alphabet.length)]].join();
  }

  /// `live/info?authorId=` → the room; live when it has a `liveId`.
  static LiveRoom roomDetail(String body, {required String authorId, int status = 200}) {
    final parsed = root(body, status: status, what: 'live/info');
    final result = (parsed['result'] as num?)?.toInt();
    if (result != 0) {
      throw SiteApiChangedError('acfun live/info: result $result');
    }
    final user = parsed['user'];
    final userId = user is Map<String, Object?> ? user['id']?.toString() ?? '' : '';
    final name = user is Map<String, Object?> ? user['name']?.toString() ?? '' : '';
    if (user is! Map<String, Object?> || userId.isEmpty || userId == '0' || name.isEmpty) {
      throw SiteNotFoundError('acfun live/info: no author $authorId');
    }
    final live = (parsed['liveId']?.toString() ?? '').isNotEmpty;
    final covers = parsed['coverUrls'];
    final count = (parsed['onlineCount'] as num?)?.toInt();
    final type = parsed['type'];
    final createTime = (parsed['createTime'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.acfun,
      roomId: authorId,
      title: parsed['title']?.toString() ?? '',
      nick: name,
      avatar: authorImage(user['headUrl']),
      cover: covers is List && covers.isNotEmpty ? authorImage(covers.first) : null,
      areaName: type is Map<String, Object?> ? type['name']?.toString() : null,
      watching: count,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && createTime != null ? DateTime.fromMillisecondsSinceEpoch(createTime) : null,
    );
  }

  /// `startPlay` → the media URLs of the adaptive manifests, best
  /// representation first. `result` 1 is live; a closed broadcast
  /// (`result` 5) is a "not found" condition; anything else is risk
  /// control.
  static List<LivePlayLine> playLines(String body, {int status = 200}) {
    final parsed = root(body, status: status, what: 'startPlay');
    final result = (parsed['result'] as num?)?.toInt();
    if (result == 5) {
      throw const SiteNotFoundError('acfun startPlay: broadcast ended');
    }
    if (result != 1) {
      throw SiteRiskControlError('acfun startPlay: result $result ${parsed['error_msg'] ?? ''}'.trim());
    }
    final data = parsed['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('acfun startPlay: no data');
    }
    var videoPlayRes = data['videoPlayRes'];
    if (videoPlayRes is String) {
      try {
        videoPlayRes = jsonDecode(videoPlayRes);
      } on FormatException {
        videoPlayRes = null;
      }
    }
    final manifests = videoPlayRes is Map<String, Object?> ? videoPlayRes['liveAdaptiveManifest'] : null;
    if (manifests is! List) {
      throw const SiteApiChangedError('acfun startPlay: no liveAdaptiveManifest');
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final manifest in manifests) {
      final adaptation = manifest is Map<String, Object?> ? manifest['adaptationSet'] : null;
      final representations = adaptation is Map<String, Object?> ? adaptation['representation'] : null;
      if (representations is! List) {
        continue;
      }
      for (final raw in representations) {
        if (raw is! Map<String, Object?>) {
          continue;
        }
        final url = raw['url']?.toString() ?? '';
        if (!url.startsWith('http') || !seen.add(url)) {
          continue;
        }
        lines.add(
          LivePlayLine(
            url: url,
            headers: apiHeaders,
            format: url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
            codec: raw['name']?.toString(),
            lineId: raw['id']?.toString(),
          ),
        );
      }
    }
    if (lines.isEmpty) {
      throw const SiteNotFoundError('acfun startPlay: nothing playable');
    }
    return lines;
  }

  /// `startPlay` → what the danmaku link needs from the same answer the
  /// streams come from: the broadcast id, its tickets (in order) and the enter
  /// attachment. `result` follows [playLines]' rules; a live answer with no
  /// `liveId` is a changed API.
  static ({String liveId, List<String> tickets, String enterRoomAttach}) danmakuParams(
    String body, {
    int status = 200,
  }) {
    final parsed = root(body, status: status, what: 'startPlay');
    final result = (parsed['result'] as num?)?.toInt();
    if (result == 5) {
      throw const SiteNotFoundError('acfun startPlay: broadcast ended');
    }
    if (result != 1) {
      throw SiteRiskControlError('acfun startPlay: result $result ${parsed['error_msg'] ?? ''}'.trim());
    }
    final data = parsed['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('acfun startPlay: no data');
    }
    final liveId = data['liveId']?.toString() ?? '';
    if (liveId.isEmpty) {
      throw const SiteApiChangedError('acfun startPlay: no liveId');
    }
    final available = data['availableTickets'];
    final tickets = [
      for (final ticket in available is List ? available : const [])
        if (ticket?.toString() case final text? when text.isNotEmpty) text,
    ];
    return (liveId: liveId, tickets: tickets, enterRoomAttach: data['enterRoomAttach']?.toString() ?? '');
  }

  /// `channel/list` → one page of rooms and the cursor after them.
  ///
  /// The envelope is `channelListData` (with the bare answer as a fallback),
  /// whose `liveList` carries the cards and whose `pcursor` carries the
  /// cursor for the next page; the cursor arrives as a string or a number
  /// depending on the endpoint's mood, so both are accepted. Cards whose
  /// author id is not an AcFun author id are dropped — the list mixes in
  /// banner and advertisement entries, and a card the site cannot open is
  /// worse than a missing one.
  static ({List<LiveRoom> rooms, String? nextCursor}) directory(
    String body,
    String Function(Map<String, Object?> item) authorIdOf, {
    int status = 200,
  }) {
    final root = AcfunParser.root(body, status: status, what: 'channel/list');
    final nested = SiteJson.object(root['channelListData']);
    final data = nested.isEmpty ? root : nested;
    final result = SiteCounts.integer(data['result']);
    if (result != null && result != 0) {
      throw SiteApiChangedError('acfun channel/list: result $result');
    }
    final rooms = <LiveRoom>[
      for (final item in SiteJson.objects(data['liveList']))
        if (authorIdOf(item).isNotEmpty) _listRoom(item, authorIdOf(item)),
    ];
    final cursor = SiteText.trimmed(data['pcursor']);
    final next = cursor.isEmpty || cursor == 'no_more' ? null : cursor;
    return (rooms: rooms, nextCursor: next);
  }

  /// One directory card.
  ///
  /// The card carries the same fields as `live/info` (the site renders both
  /// with one component), so the same reading applies: the author id is the
  /// room identity, the online count is a concurrent-viewer reading, and a
  /// card with a `liveId` is on air.
  static LiveRoom _listRoom(Map<String, Object?> item, String authorId) {
    final user = SiteJson.object(item['user']);
    final covers = SiteJson.list(item['coverUrls']);
    final type = SiteJson.object(item['type']);
    final live = SiteText.trimmed(item['liveId']).isNotEmpty;
    return LiveRoom(
      platform: SiteIds.acfun,
      roomId: authorId,
      title: SiteText.title(SiteText.text(item['title'])),
      nick: SiteText.title(SiteText.text(user['name'])),
      avatar: authorImage(user['headUrl']),
      cover: authorImage(covers.isEmpty ? null : covers.first),
      areaName: SiteText.trimmed(type['name']),
      watching: SiteCounts.integer(item['onlineCount']),
      onlineViewers: SiteCounts.integer(item['onlineCount']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedAt(item['createTime'] ?? item['liveStartTime']) : null,
    );
  }

  /// When a broadcast started: epoch milliseconds, or null for 0 and for
  /// values that are plainly seconds (a millisecond timestamp before 2001).
  static DateTime? _startedAt(Object? value) {
    final millis = SiteCounts.integer(value);
    if (millis == null || millis <= 0) {
      return null;
    }
    final seconds = millis < 1000000000000 ? millis * 1000 : millis;
    return DateTime.fromMillisecondsSinceEpoch(seconds);
  }

  /// The `filters` query value of an area: its filter type and id, JSON as
  /// the endpoint expects it.
  static String filterQuery({required int type, required int id}) => jsonEncode([
    {'filterType': type, 'filterId': id},
  ]);

  /// The area id that means "everything": a listing filtered by it is the
  /// same as the recommendations, so it is sent as no filter at all.
  static const int allFilterId = 0;

  static final RegExp _authorId = RegExp(r'^\d+$');

  /// Whether [value] is an AcFun author id (digits only): the identity of a
  /// room on this platform is its author, not a numeric room id.
  static bool isAuthorId(String value) => _authorId.hasMatch(value.trim());

  /// A listing answer's `channelFilters` → the site's channel filters,
  /// flattened.
  ///
  /// The filters are grouped for display (`liveChannelDisplayFilters`), and
  /// the group's name is what a picker shows as the heading — which is why it
  /// becomes the area's parent id rather than being dropped: the ids stay
  /// what `getCategoryRooms` accepts, and the group survives as context.
  /// The `全部` filter of each group is skipped, because it means "no filter"
  /// and listing it as an area would offer the same rooms under a second
  /// name.
  static List<LiveArea> channelAreas(Map<String, Object?> root) {
    final groups = SiteJson.list(SiteJson.object(root['channelFilters'])['liveChannelDisplayFilters']);
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (final group in groups) {
      final groupMap = SiteJson.object(group);
      final groupName = SiteText.title(SiteText.text(groupMap['name']));
      for (final filter in SiteJson.list(groupMap['displayFilters'])) {
        final filterMap = SiteJson.object(filter);
        final id = SiteText.trimmed(filterMap['filterId']);
        final type = SiteText.trimmed(filterMap['filterType']);
        final name = SiteText.title(SiteText.text(filterMap['name']));
        if (id.isEmpty || name.isEmpty || id == '0' || !seen.add('$type:$id')) {
          continue;
        }
        areas.add(
          LiveArea(
            id: id,
            name: name,
            parentId: type.isEmpty ? null : type,
            sort: SiteCounts.integer(filterMap['sort']) ?? 0,
          ),
        );
      }
      if (groupName.isEmpty) {
        continue;
      }
    }
    return areas;
  }

  /// Normalizes a possibly relative image path to an absolute URL.
  static String? authorImage(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
