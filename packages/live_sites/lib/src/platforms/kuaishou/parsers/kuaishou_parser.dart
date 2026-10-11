import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Kuaishou live APIs.
///
/// Two payload families are read here. The *page* state
/// (`window.__INITIAL_STATE__`) carries one room in full; the *directory*
/// endpoints answer `{data: {list: […]}}` with either game categories or
/// room cards. The two share the card shape (`liveStream`, `author`,
/// `gameInfo`, `isLiving`), which is what lets one mapping serve both.
abstract final class KuaishouParser {
  /// Request headers for the web endpoints.
  static const Map<String, String> webHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://live.kuaishou.com/',
  };

  /// The state marker of a room page.
  static final RegExp _stateMarker = RegExp(r'window\.__INITIAL_STATE__\s*=\s*');
  static final RegExp _challenge = RegExp('verify|captcha|challenge', caseSensitive: false);

  /// Decodes a JSON answer, rejecting the site's verification pages as risk
  /// control rather than as an API change: they are a state the user can fix
  /// by opening the site once, not a broken adapter.
  static Map<String, Object?> json(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kuaishou $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      if (_challenge.hasMatch(body)) {
        throw SiteRiskControlError('kuaishou $what: verification page');
      }
      throw SiteApiChangedError('kuaishou $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('kuaishou $what: body is not an object');
    }
    return decoded;
  }

  /// The `data` object of a directory answer.
  static Map<String, Object?> listPayload(Map<String, Object?> root, {required String what}) {
    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('kuaishou $what: no data object');
    }
    return data;
  }

  /// The home listing → one page of rooms.
  ///
  /// The home answer is a list of *sections* (`labelName`: 热推直播, the
  /// boards), each holding `gameLiveInfo` entries, each holding `liveInfo`
  /// entries — the rooms. Flattening that is what the site's own page does
  /// to draw its carousels, and a parser that read `data.list` as the rooms
  /// found none at all.
  static LivePage<LiveRoom> homeRooms(Map<String, Object?> root) {
    final data = listPayload(root, what: 'home/list');
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    for (final section in SiteJson.list(data['list'])) {
      final sectionMap = SiteJson.object(section);
      final sectionName = SiteText.title(SiteText.text(sectionMap['labelName']));
      for (final group in SiteJson.list(sectionMap['gameLiveInfo'])) {
        final groupMap = SiteJson.object(group);
        final groupLabel = SiteText.title(SiteText.text(groupMap['subLabelName']));
        // The group's label is the site's own statement about its cards
        // (`直播中` is on air); the per-card flag is not always present, so
        // the label is the fallback that tells a live card from an upcoming
        // one.
        final inLiveGroup = groupLabel == '直播中';
        for (final item in SiteJson.list(groupMap['liveInfo'])) {
          final card = SiteJson.object(item);
          final room = liveCard(card, defaultArea: sectionName.isEmpty ? groupLabel : sectionName, live: inLiveGroup);
          if (room != null && seen.add(room.roomId)) {
            rooms.add(room);
          }
        }
      }
    }
    // The home answer is everything the endpoint has; it has no second page.
    return LivePage<LiveRoom>(items: rooms);
  }

  /// A board listing's room cards → one page of rooms.
  static LivePage<LiveRoom> roomList(Map<String, Object?> root, {required String what, String? defaultArea}) {
    final data = listPayload(root, what: what);
    final rooms = <LiveRoom>[
      for (final card in SiteJson.list(data['list']))
        if (card is Map<String, Object?>) ?liveCard(card, defaultArea: defaultArea),
    ];
    final hasMore = SiteCounts.flag(data['hasMore']) ?? (rooms.length >= 20);
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore);
  }

  /// A search answer's rows → the streamers it names, as anchors.
  ///
  /// The same cards the room reading maps, read as people: `id` is the
  /// author and doubles as the broadcast id when they are live (`living`,
  /// or a `liveStream` that is actually populated — the flag alone is not
  /// always present), the follower count is what the card reports, and a
  /// card without an id names nobody and is dropped.
  static LivePage<LiveAnchor> anchorList(Map<String, Object?> root, {String? what}) {
    final data = listPayload(root, what: what ?? 'search');
    final cards = SiteJson.list(data['list']);
    final anchors = <LiveAnchor>[
      for (final card in cards)
        if (card is Map<String, Object?>)
          if (SiteText.trimmed(card['id']) case final id when id.isNotEmpty) _anchor(card, id),
    ];
    return LivePage<LiveAnchor>(items: anchors, hasMore: SiteCounts.flag(data['hasMore']) ?? anchors.length >= 20);
  }

  /// One anchor row.
  ///
  /// The author search answers rows about *people*, not cards about rooms,
  /// so the fields sit at the top level (`name`, `avatar`, `living`) rather
  /// than under `author`, and the follower count is a display string
  /// (`"1943.3w"`) rather than a number — reading the directory's fields, as
  /// this first did, produced anchors with no names.
  static LiveAnchor _anchor(Map<String, Object?> card, String id) {
    final living = SiteCounts.flag(card['living']) ?? SiteCounts.flag(card['isLiving']) ?? false;
    final counts = SiteJson.object(card['counts']);
    final bio = SiteText.title(SiteText.text(card['description']));
    return LiveAnchor(
      id: id,
      roomId: living ? id : null,
      name: SiteText.title(SiteText.text(card['name'])),
      avatar: SiteText.trimmed(card['avatar']).isEmpty ? null : SiteText.trimmed(card['avatar']),
      live: living,
      count: SiteCounts.scaled(counts['fan']),
      bio: bio.isEmpty ? null : bio,
    );
  }

  /// One live card, or null when it is not a room.
  ///
  /// The card's `id` *is* the broadcast's live stream id — the value the
  /// comment feed is polled with — which is why the room id is taken from it:
  /// a card whose id is missing cannot be opened *or* subscribed to, so it is
  /// dropped rather than given a made-up identity.
  static LiveRoom? liveCard(Map<String, Object?> card, {String? defaultArea, bool? live}) {
    final id = SiteText.trimmed(card['id']);
    if (id.isEmpty) {
      return null;
    }
    final author = SiteJson.object(card['author']);
    final game = SiteJson.object(card['gameInfo']);
    final areaName = SiteText.title(SiteText.text(game['name']));
    // The on-air marker is the card's `type` (`live`), not its `living`
    // field: every card in the site's own 直播中 groups carries
    // `living: false`, so trusting that field marked live rooms offline —
    // which is what left the home listing with nothing to subscribe to.
    // `isLiving` and the enclosing group's label are the fallbacks.
    final type = SiteText.trimmed(card['type']).toLowerCase();
    final living = type == 'live' || (SiteCounts.flag(card['isLiving']) ?? live ?? false);
    return LiveRoom(
      platform: SiteIds.kuaishou,
      roomId: id,
      title: SiteText.title(SiteText.text(card['caption'] ?? card['title'])),
      nick: SiteText.title(SiteText.text(author['name'])),
      avatar: SiteText.trimmed(author['avatar']).isEmpty ? null : SiteText.trimmed(author['avatar']),
      cover: _cover(card['poster']),
      areaName: areaName.isEmpty ? defaultArea : areaName,
      watching: SiteCounts.integer(card['watchingCount']),
      status: living ? LiveStatus.live : LiveStatus.offline,
    );
  }

  /// The live stream id a card or play item carries, or null when the room is
  /// not on air.
  ///
  /// On this platform the broadcast id and the room id are the same string,
  /// so the id the feed is polled with is the room's own — which is what
  /// makes a card a complete danmaku argument as soon as it is read.
  static String? liveStreamId(Map<String, Object?> playItem) {
    final stream = playItem['liveStream'];
    if (stream is Map<String, Object?>) {
      final nested = SiteText.trimmed(stream['id']);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    final direct = SiteText.trimmed(playItem['id']);
    return direct.isEmpty ? null : direct;
  }

  /// A directory answer's game categories → the areas of one board.
  ///
  /// The category list is what the site's own side bar shows; each entry
  /// carries the game id the room list is filtered by and the board it
  /// belongs to (`categoryName`), which becomes the area's parent label.
  static List<LiveArea> areas(Map<String, Object?> root, {required String what}) {
    final data = listPayload(root, what: what);
    final entries = SiteJson.list(data['list']);
    return [
      for (final entry in entries)
        if (entry is Map<String, Object?>)
          if (SiteText.trimmed(entry['id']) case final id when id.isNotEmpty)
            LiveArea(
              id: id,
              name: SiteText.title(SiteText.text(entry['name'])),
              parentId: SiteText.trimmed(entry['categoryName']).isEmpty
                  ? null
                  : SiteText.trimmed(entry['categoryName']),
            ),
    ];
  }

  /// One directory card, or null when it is not a room.
  ///
  /// The card carries the same fields the room page's `playItem` does, so the
  /// mapping is shared with [roomDetail]'s shape rather than duplicated: a
  /// card without an author id and without a room id is an advertisement, and
  /// those are dropped.
  static LiveRoom? roomCard(Map<String, Object?> card, {String? defaultArea}) {
    final author = SiteJson.object(card['author']);
    final stream = SiteJson.object(card['liveStream']);
    final game = SiteJson.object(card['gameInfo']);
    final roomId = SiteText.trimmed(author['id']).isEmpty
        ? SiteText.trimmed(card['id']).isEmpty
              ? SiteText.trimmed(author['userId'])
              : SiteText.trimmed(card['id'])
        : SiteText.trimmed(author['id']);
    // `author.id` is the principal id the site addresses a room by; the
    // page's room id is the same value, which is why a card carries it under
    // one of the two.
    final id = SiteText.trimmed(card['roomId']).isEmpty
        ? (roomId.isEmpty ? SiteText.trimmed(stream['id']) : roomId)
        : SiteText.trimmed(card['roomId']);
    if (id.isEmpty) {
      return null;
    }
    final living = SiteCounts.flag(card['isLiving']) ?? stream.isNotEmpty;
    final areaName = SiteText.title(SiteText.text(game['name']));
    return LiveRoom(
      platform: SiteIds.kuaishou,
      roomId: id,
      title: SiteText.title(SiteText.text(stream['caption'] ?? card['title'])),
      nick: SiteText.title(SiteText.text(author['name'])),
      avatar: SiteText.trimmed(author['avatar']).isEmpty ? null : SiteText.trimmed(author['avatar']),
      cover: _cover(stream['poster']),
      areaName: areaName.isEmpty ? defaultArea : areaName,
      watching: SiteCounts.integer(stream['watchingCount']),
      status: living ? LiveStatus.live : LiveStatus.offline,
    );
  }

  /// The page's initial state object.
  static Map<String, Object?> initialState(String html, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kuaishou room page: HTTP $status');
    }
    if (_challenge.hasMatch(html)) {
      throw const SiteRiskControlError('kuaishou room page: verification page');
    }
    final marker = _stateMarker.firstMatch(html);
    if (marker == null) {
      throw const SiteApiChangedError('kuaishou room page: no __INITIAL_STATE__');
    }
    final start = marker.end;
    final literal = objectLiteral(html, start);
    if (literal == null) {
      throw const SiteApiChangedError('kuaishou room page: __INITIAL_STATE__ is not an object');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(literal);
    } on FormatException {
      throw const SiteApiChangedError('kuaishou room page: __INITIAL_STATE__ is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('kuaishou room page: __INITIAL_STATE__ is not an object');
    }
    return decoded;
  }

  /// The balanced `{…}` literal starting at or after [start].
  static String? objectLiteral(String text, int start) {
    var index = start;
    while (index < text.length && text[index] != '{') {
      index++;
    }
    if (index >= text.length) {
      return null;
    }
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var cursor = index; cursor < text.length; cursor++) {
      final char = text[cursor];
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
        continue;
      }
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(index, cursor + 1);
        }
      }
    }
    return null;
  }

  /// The room item of a page state (`liveroom.playList[0]`).
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

  /// The page's emote table: the site's `[…]` codes and the pictures they
  /// stand for, which the comment feed itself does not carry.
  static Map<String, String> emoteTable(Map<String, Object?> state) {
    final table = <String, String>{};
    for (final entry in SiteJson.object(state['emoji']).entries) {
      final url = SiteText.trimmed(entry.value);
      if (entry.key.isNotEmpty && url.isNotEmpty) {
        table[entry.key] = url.startsWith('//') ? 'https:$url' : url;
      }
    }
    return table;
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
      throw const SiteNotFoundError('kuaishou: no liveStream on the page');
    }
    final urls = stream['playUrls'];
    if (urls is! Map<String, Object?>) {
      throw const SiteNotFoundError('kuaishou: no playUrls on the page');
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    _collect(urls, null, null, lines, seen);
    if (lines.isEmpty) {
      throw const SiteNotFoundError('kuaishou: no line with a URL');
    }
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
    final quality = node['name']?.toString() ?? node['quality']?.toString() ?? node['level']?.toString();
    final url = node['url']?.toString() ?? '';
    if (url.startsWith('http')) {
      final format = url.contains('.m3u8')
          ? StreamFormat.hls
          : url.contains('.flv')
          ? StreamFormat.flv
          : StreamFormat.other;
      if (seen.add(url)) {
        lines.add(LivePlayLine(url: url, format: format, codec: codec, lineId: quality ?? label, headers: webHeaders));
      }
    }
    for (final entry in node.entries) {
      _collect(entry.value, entry.key, _codecOf(entry.key) ?? codec, lines, seen);
    }
  }

  static String? _codecOf(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('hevc') || lower.contains('h265')) {
      return 'hevc';
    }
    if (lower.contains('avc') || lower.contains('h264')) {
      return 'avc';
    }
    return null;
  }

  static String? _cover(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : (url.startsWith('//') ? 'https:$url' : url);
  }
}
