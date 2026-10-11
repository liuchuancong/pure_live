import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the NetEase CC web APIs.
abstract final class CcParser {
  static final RegExp _htmlPage = RegExp(r'^\s*<', multiLine: true);

  /// Decodes a JSON body; an HTML body is an API change (the site served
  /// a page where JSON was expected).
  static Map<String, Object?> decode(String body, {int status = 200, String what = 'response'}) {
    if (status != 200 && body.trimLeft().startsWith(_htmlPage)) {
      throw SiteApiChangedError('cc $what: HTTP $status (HTML page)');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('cc $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('cc $what: body is not an object');
    }
    return decoded;
  }

  /// `activitylives/anchor/lives` → the live channel id for [ccid], or
  /// null when the anchor has none.
  static String? liveChannel(String body, {required String ccid, int status = 200}) {
    if (status == 400) {
      throw SiteNotFoundError('cc activitylives: HTTP 400 for $ccid');
    }
    final root = decode(body, status: status, what: 'activitylives');
    if (root['code']?.toString() != 'OK') {
      throw SiteApiChangedError('cc activitylives: code ${root['code']}');
    }
    final data = root['data'];
    final entry = data is Map<String, Object?> ? data[ccid] : null;
    if (entry is! Map<String, Object?>) {
      throw SiteApiChangedError('cc activitylives: no entry for $ccid');
    }
    final channel = entry['channel_id']?.toString();
    return channel == null || channel.isEmpty ? null : channel;
  }

  /// `live/channel/?channelids=` → the room broadcasting in the channel.
  /// Null when the channel no longer broadcasts (`nolive` or no rows).
  /// The room identity keeps the [ccid] the user asked for; the media
  /// channel id rides in `data` as `channel`.
  static LiveRoom? channelRoom(String body, {required String ccid, int status = 200}) {
    final root = decode(body, status: status, what: 'live/channel');
    final rows = root['data'];
    if (rows != null && rows is! List) {
      throw const SiteApiChangedError('cc live/channel: data is not a list');
    }
    final room = rows is List && rows.isNotEmpty ? rows.first : null;
    if (room is! Map<String, Object?> || room['nolive']?.toString() == '1') {
      return null;
    }
    final answered = room['ccid']?.toString() ?? room['cuteid']?.toString() ?? '';
    if (answered != ccid) {
      throw SiteApiChangedError('cc live/channel: answered ccid $answered for $ccid');
    }
    final statusText = room['status']?.toString();
    final title = room['title']?.toString() ?? '';
    final isReplay = title.startsWith('【重播】');
    final live = statusText == '1' && !isReplay;
    final popularity = room['hot']?.toString() ?? '';
    final online = room['online']?.toString() ?? '';
    final followers = room['follower_num']?.toString() ?? '';
    final watching = int.tryParse(popularity.isNotEmpty ? popularity : (online.isNotEmpty ? online : followers));
    return LiveRoom(
      platform: SiteIds.cc,
      roomId: ccid,
      data: room['cid']?.toString() ?? room['channel_id']?.toString(),
      title: title,
      nick: room['nickname']?.toString() ?? '',
      avatar: _image(room['purl']),
      cover: _image(room['cover'] ?? room['poster']),
      areaName: room['gamename']?.toString(),
      watching: watching,
      status: isReplay ? LiveStatus.replay : (live ? LiveStatus.live : LiveStatus.offline),
    );
  }

  /// The offline room for an anchor with no live channel: identity and
  /// state only; a merge keeps everything stored.
  static LiveRoom offlineRoom(String ccid) => LiveRoom(platform: SiteIds.cc, roomId: ccid, status: LiveStatus.offline);

  /// `video_play_url` payload → the play data (already the `data`
  /// object).
  static Map<String, Object?> playData(String body, {int status = 200}) {
    if (status == 410 || status == 404) {
      throw SiteNotFoundError('cc video_play_url: HTTP $status');
    }
    final data = decode(body, status: status, what: 'video_play_url');
    return data;
  }

  /// The quality codes of a play answer: `vbrname_list` in platform
  /// order, falling back to the single `vbrname_sel`.
  static List<LivePlayQuality> qualities(Map<String, Object?> data) {
    final codes = <String>[];
    final rawCodes = data['vbrname_list'];
    if (rawCodes is List) {
      for (final code in rawCodes) {
        final text = code?.toString() ?? '';
        if (text.isNotEmpty) {
          codes.add(text);
        }
      }
    }
    if (codes.isEmpty) {
      final selected = data['vbrname_sel']?.toString();
      if (selected == null) {
        throw const SiteApiChangedError('cc video_play_url: no vbrname_list or vbrname_sel');
      }
      codes.add(selected);
    }
    return [
      for (final (index, code) in codes.toSet().toList().indexed)
        LivePlayQuality(quality: index, label: code == 'original' ? '原画' : code, sort: codes.length - index),
    ];
  }

  /// Play lines from a play answer: the answered line (`videourl`) plus
  /// the backup (`bakvideourl`).
  static List<LivePlayLine> playLines(Map<String, Object?> data, String ccid, {required String cdn}) {
    final lines = <LivePlayLine>[];
    for (final (urlKey, cdnKey) in const [('videourl', 'cdn_sel'), ('bakvideourl', 'bakcdn_sel')]) {
      final url = data[urlKey]?.toString() ?? '';
      if (!url.startsWith('http')) {
        continue;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(ccid),
          format: url.toLowerCase().endsWith('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
          lineId: cdnKey == 'cdn_sel' ? cdn : '$cdn-bak',
        ),
      );
    }
    return lines;
  }

  /// Media headers: UA, Origin and the room page as Referer. CC has no
  /// cookie.
  /// The headers a directory or search request needs: CC answers HTML to a
  /// request without an `Accept`, and the JSON listings are what the page
  /// wants.
  static const Map<String, String> apiHeaders = SiteHeaders.json;

  /// Media headers: the room page as Referer, which the play endpoint
  /// checks.
  static Map<String, String> mediaHeaders(String roomId) {
    final id = Uri.encodeComponent(roomId.trim());
    return {
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'origin': 'https://cc.163.com',
      'referer': id.isEmpty ? 'https://cc.163.com/' : 'https://cc.163.com/$id/',
    };
  }

  /// The media lease expiry encoded in a media URL's `auth_key`: the first field of
  /// its `auth_key` is the Unix expiry (issued + 300 s).
  static DateTime? leaseExpiry(String url) {
    final match = RegExp(r'(?:^|&)auth_key=(\d+)-').firstMatch(Uri.parse(url).query);
    final seconds = match == null ? null : int.tryParse(match.group(1)!);
    return seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  /// `api/category/live/` or `api/category/<game>/` → one page of rooms.
  ///
  /// Both listings answer the same shape: a `lives` array whose rows carry
  /// the room id as `cuteid` (a positive integer or a digit string), the
  /// heat and concurrent-viewer counters side by side, and the area under
  /// `game_name` or `gamename` depending on the endpoint. Rows without a
  /// usable `cuteid` are skipped: the site pads its lists with
  /// advertisements, and a card with the room id "null" (which a naive
  /// mapping produced) can never open.
  ///
  /// [gametype] is the area the request was made for, so the parser can
  /// reject an answer for a different area rather than label its rooms
  /// wrongly; null accepts any area and reads it from the row.
  static LivePage<LiveRoom> roomList(Map<String, Object?> data, {String? gametype}) {
    final announced = SiteText.trimmed(data['gametype']);
    if (gametype != null && announced.isNotEmpty && announced != gametype) {
      throw SiteApiChangedError('cc category: answered $announced for $gametype');
    }
    final rows = SiteJson.list(data['lives']);
    final rooms = <LiveRoom>[
      for (final row in rows)
        if (row is Map<String, Object?>)
          if (_cuteId(row['cuteid']) case final id?)
            _listRoom(
              row,
              id,
              area: SiteText.trimmed(row['game_name']).isEmpty
                  ? SiteText.trimmed(row['gamename'])
                  : SiteText.trimmed(row['game_name']),
            ),
    ];
    // The listings have no page count, so "more" is the honest answer for a
    // full page and "no more" for a short one.
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.length >= _fullPageHint);
  }

  /// `search/anchor/` → the streamers matching a keyword, live or not.
  ///
  /// A search card's heat is `hot_score` alone: the `visitor` field it also
  /// carries counts every profile view, offline streamers included, so using
  /// it as a viewer count would show a room as lively while it is dark.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> data) {
    final anchors = SiteJson.object(data['webcc_anchor']);
    final rooms = <LiveRoom>[
      for (final row in SiteJson.list(anchors['result']))
        if (row is Map<String, Object?>)
          if (_cuteId(row['cuteid']) case final id?) _searchRoom(row, id),
    ];
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.length >= _fullPageHint);
  }

  /// The row count above which a listing is assumed to have another page.
  ///
  /// Neither endpoint reports a total, so this is a heuristic — and it is
  /// marked as one: a full page almost always means more, a short page
  /// means the end.
  static const int _fullPageHint = 20;

  /// One directory card.
  static LiveRoom _listRoom(Map<String, Object?> item, String roomId, {required String area}) {
    final audience = _audience(item);
    final status = _onAirStatus(_status(item['status']), item['title']);
    return LiveRoom(
      platform: SiteIds.cc,
      roomId: roomId,
      title: SiteText.title(SiteText.text(item['title'])),
      nick: SiteText.title(SiteText.text(item['nickname'])),
      avatar: _image(item['purl']),
      cover: _image(item['cover'] ?? item['poster']),
      areaName: area,
      watching: audience.online ?? audience.popularity,
      status: status,
      startedAt: _onAir(status) ? _startedAt(item['startat']) : null,
    );
  }

  /// One search card, which reports the viewer count separately from the
  /// heat and falls back to the portrait for a cover.
  static LiveRoom _searchRoom(Map<String, Object?> item, String roomId) {
    final portrait = _image(item['portrait']) ?? _image(item['portraiturl']);
    final status = (SiteCounts.integer(item['status']) ?? 0) == 1 ? LiveStatus.live : LiveStatus.offline;
    return LiveRoom(
      platform: SiteIds.cc,
      roomId: roomId,
      title: SiteText.title(SiteText.text(item['title'] ?? item['nickname'])),
      nick: SiteText.title(SiteText.text(item['nickname'])),
      avatar: _image(item['purl']) ?? portrait,
      cover: _image(item['cover']) ?? portrait,
      areaName: SiteText.trimmed(item['gamename']),
      watching: SiteCounts.integer(item['hot_score']),
      status: status,
    );
  }

  /// The heat and the concurrent-viewer counters, each under whichever of
  /// its field names this endpoint uses. The heat may be a display string
  /// ("1.2万"), which is why it is read as a scaled count.
  static ({int? popularity, int? online}) _audience(Map<String, Object?> room) {
    int? first(List<String> keys) {
      for (final key in keys) {
        final value = SiteCounts.scaled(room[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    return (
      popularity: first(const ['webcc_visitor', 'hot_score', 'visitor', 'total_visitor']),
      online: first(const ['vision_visitor', 'online_num']),
    );
  }

  /// `search/anchor/` → the streamers matching a keyword, as anchors.
  ///
  /// The same answer the room search reads, seen as people instead: a
  /// streamer who is not broadcasting still has an id and a name to show and
  /// follow, while `cuteid` doubles as the room to open when they are on
  /// air. The count is the follower total the site reports — search's own
  /// `visitor` counts every profile view, offline streamers included, so it
  /// is not an audience.
  static LivePage<LiveAnchor> searchAnchors(Map<String, Object?> data) {
    final anchors = SiteJson.object(data['webcc_anchor']);
    final rows = SiteJson.objects(anchors['result']);
    return LivePage<LiveAnchor>(
      items: [
        for (final row in rows)
          if (SiteText.trimmed(row['cuteid']).isNotEmpty)
            LiveAnchor(
              id: SiteText.trimmed(row['cuteid']),
              roomId: SiteCounts.integer(row['status']) == 1 ? SiteText.trimmed(row['cuteid']) : null,
              name: SiteText.title(SiteText.text(row['nickname'])),
              avatar: SiteText.trimmed(row['portrait'] ?? row['portraiturl']).isEmpty
                  ? null
                  : SiteText.trimmed(row['portrait'] ?? row['portraiturl']),
              live: SiteCounts.integer(row['status']) == 1,
              count: SiteCounts.integer(row['follower_num']),
            ),
      ],
      hasMore: rows.length >= _fullPageHint,
    );
  }

  /// A room id: a positive integer within the safe range, or a digit string.
  static String? _cuteId(Object? value) {
    if (value is int) {
      return value > 0 && value <= 9007199254740991 ? '$value' : null;
    }
    final text = SiteText.trimmed(value);
    return RegExp(r'^\d{1,18}$').hasMatch(text) && text != '0' ? text : null;
  }

  static LiveStatus _status(Object? value) => switch (SiteCounts.integer(value)) {
    1 => LiveStatus.live,
    0 => LiveStatus.offline,
    _ => LiveStatus.unknown,
  };

  /// Whether a room is on air, with the site's own "【重播】" prefix marking a
  /// rebroadcast as a replay rather than a live stream.
  static LiveStatus _onAirStatus(LiveStatus status, Object? title) =>
      status == LiveStatus.live && SiteText.trimmed(title).startsWith('【重播】') ? LiveStatus.replay : status;

  static bool _onAir(LiveStatus status) => status == LiveStatus.live || status == LiveStatus.replay;

  /// When a broadcast went on air; `startat` is Beijing time as epoch
  /// seconds.
  static DateTime? _startedAt(Object? value) {
    final seconds = SiteCounts.integer(value);
    return seconds == null || seconds <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
