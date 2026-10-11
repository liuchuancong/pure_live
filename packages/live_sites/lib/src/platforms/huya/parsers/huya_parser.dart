import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Huya room page: the room state lives in a
/// `window.TT_ROOM_DATA = {…}` script blob and the stream table in
/// `window.HYPlayerConfig = {…}`.
abstract final class HuyaParser {
  static final RegExp _roomData = RegExp(r'window\.TT_ROOM_DATA\s*=\s*(\{[^;]*?\});', dotAll: true);

  static final RegExp _playerConfig = RegExp(r'window\.HYPlayerConfig\s*=\s*(\{[^;]*?\});', dotAll: true);

  static final RegExp _htmlPage = RegExp(r'^\s*<!(?:DOCTYPE|html)', caseSensitive: false);

  static final RegExp _scriptEscape = RegExp('</?script[^>]*>');

  /// Whether the body is an HTML page at all (offline rooms still return
  /// the page; a non-HTML body means the flow changed).
  static bool looksLikeHtml(String body) => _htmlPage.hasMatch(body.trimLeft());

  /// Extracts the room snapshot from the page. Throws "not found" when
  /// the TT_ROOM_DATA blob is absent (unknown room ids lead to a 404
  /// page without the blob).
  static LiveRoom roomDetail(String html, {required String requestedId}) {
    if (!looksLikeHtml(html)) {
      throw SiteApiChangedError('huya/$requestedId: body is not HTML');
    }
    final blob = _roomData.firstMatch(html)?.group(1);
    if (blob == null) {
      throw SiteNotFoundError('huya/$requestedId: no TT_ROOM_DATA on the page');
    }
    final data = _decode(blob);
    final introduction = data['introduction']?.toString() ?? '';
    final state = (data['state'] as num?)?.toInt() ?? 0;
    final isReplay = data['isReplay']?.toString() == '1';
    return LiveRoom(
      platform: SiteIds.huya,
      roomId: requestedId,
      title: introduction,
      nick: data['nick']?.toString() ?? '',
      avatar: data['avatar180']?.toString(),
      cover: data['screenshot']?.toString(),
      areaName: data['gameFullName']?.toString(),
      watching: (data['gg_total_count'] as num?)?.toInt(),
      status: isReplay
          ? LiveStatus.replay
          : state == 2
          ? LiveStatus.live
          : state == 3
          ? LiveStatus.carousel
          : LiveStatus.offline,
    );
  }

  /// Extracts the playable lines from `HYPlayerConfig.streamBase`:
  /// one entry per (cdn, rate) combination.
  static List<LivePlayLine> playLines(String html) {
    final blob = _playerConfig.firstMatch(html)?.group(1);
    if (blob == null) {
      throw const SiteApiChangedError('huya: no HYPlayerConfig on the page');
    }
    final config = _decode(blob);
    final base = config['streamBase'];
    final data = base is Map<String, Object?> ? base['data'] : null;
    final list = data is List && data.isNotEmpty ? data.first : null;
    final entries = list is Map<String, Object?> ? list['gameStreamInfoList'] : null;
    final lines = <LivePlayLine>[];
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map<String, Object?>) {
          continue;
        }
        final url = _url(entry);
        if (url == null) {
          continue;
        }
        lines.add(
          LivePlayLine(
            url: url,
            headers: const {
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
              'referer': 'https://www.huya.com/',
            },
            format: (url.contains('.m3u8')) ? StreamFormat.hls : StreamFormat.flv,
            codec: entry['sCdnType']?.toString() == 'AL' ? 'hevc' : 'avc',
            lineId: entry['sCdnType']?.toString(),
          ),
        );
      }
    }
    return lines;
  }

  /// The quality levels present in the stream table.
  static List<LivePlayQuality> playQualities(String html) {
    final blob = _playerConfig.firstMatch(html)?.group(1);
    if (blob == null) {
      return const [];
    }
    final config = _decode(blob);
    final base = config['streamBase'];
    final data = base is Map<String, Object?> ? base['data'] : null;
    final list = data is List && data.isNotEmpty ? data.first : null;
    final entries = list is Map<String, Object?> ? list['gameStreamInfoList'] : null;
    final seen = <int, LivePlayQuality>{};
    if (entries is List) {
      for (final entry in entries) {
        if (entry is! Map<String, Object?>) {
          continue;
        }
        final rate = (entry['iBitRate'] as num?)?.toInt();
        if (rate == null || seen.containsKey(rate)) {
          continue;
        }
        seen[rate] = LivePlayQuality(quality: rate, label: rate == 0 ? '原画' : '${rate}K', sort: seen.length);
      }
    }
    return seen.values.toList();
  }

  static String? _url(Map<String, Object?> entry) {
    final base = entry['sFlvUrl']?.toString() ?? entry['sHlsUrl']?.toString() ?? '';
    final suffix = entry['sFlvUrlSuffix']?.toString() ?? entry['sHlsUrlSuffix']?.toString() ?? '';
    final antiCode = entry['sFlvAntiCode']?.toString() ?? entry['sHlsAntiCode']?.toString() ?? '';
    if (base.isEmpty || suffix.isEmpty) {
      return null;
    }
    return '$base/$suffix?$antiCode';
  }

  /// `cache.php?m=LiveList&do=getLiveListByPage` payload → one page.
  ///
  /// The list lives in `data.datas` and the page count in `data.totalPage`,
  /// so `hasMore` is the site's own answer rather than a guess. Items
  /// without a `profileRoom` are skipped: the directory mixes in
  /// advertisements whose room id is not a number.
  static LivePage<LiveRoom> roomList(Map<String, Object?> data, {required int page}) {
    final raw = data['datas'];
    final rooms = <LiveRoom>[
      for (final item in raw is List ? raw : const <Object?>[])
        if (item is Map<String, Object?>) ?_directoryRoom(item),
    ];
    final totalPage = (data['totalPage'] as num?)?.toInt() ?? 0;
    final hasMore = rooms.isNotEmpty && (totalPage <= 0 || page < totalPage);
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore);
  }

  /// One directory item, or null when it is not a room.
  static LiveRoom? _directoryRoom(Map<String, Object?> item) {
    final roomId = _numeric(item['profileRoom']);
    if (roomId == null) {
      return null;
    }
    return LiveRoom(
      platform: SiteIds.huya,
      roomId: roomId,
      title: _title(item['introduction'], item['roomName']),
      nick: item['nick']?.toString() ?? '',
      avatar: _text(item['avatar180']).isEmpty ? null : _text(item['avatar180']),
      cover: _text(item['screenshot']).isEmpty ? null : _text(item['screenshot']),
      areaName: item['gameFullName']?.toString(),
      watching: _count(item['totalCount']),
      status: LiveStatus.live,
    );
  }

  /// `search.cdn.huya.com?m=Search&do=getSearchContent&v=4` payload → one
  /// page of live rooms.
  ///
  /// The response carries two document sets — `response.3` for rooms and
  /// `response.1` for streamers — and the room id of a live entry is the
  /// streamer's (`uid`+`yyid` match), falling back to the document's own
  /// `room_id`. A request for a later page repeats every earlier document
  /// first, so the first `start` documents are skipped and a room already
  /// seen is not repeated: without that, page two would show page one.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> response, {required int start, required int rows}) {
    final docs = _docs(response, '3');
    final streamers = _docs(response, '1');
    String? roomIdOf(Map<String, Object?> doc) {
      final uid = doc['uid']?.toString();
      final yyid = doc['yyid']?.toString();
      if (uid != null && yyid != null) {
        for (final streamer in streamers) {
          if (streamer['uid']?.toString() == uid && streamer['yyid']?.toString() == yyid) {
            final id = _numeric(streamer['room_id']);
            if (id != null) {
              return id;
            }
          }
        }
      }
      return _numeric(doc['room_id']);
    }

    final skipped = docs.length > rows ? (start < 0 ? 0 : (start > docs.length ? docs.length : start)) : 0;
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final (index, doc) in docs.indexed) {
      final roomId = roomIdOf(doc);
      if (roomId == null || index < skipped || !seen.add(roomId)) {
        continue;
      }
      rooms.add(
        LiveRoom(
          platform: SiteIds.huya,
          roomId: roomId,
          title: _title(doc['game_introduction'], doc['game_roomName']),
          nick: doc['game_nick']?.toString() ?? '',
          avatar: _text(doc['game_imgUrl']).isEmpty ? null : _text(doc['game_imgUrl']),
          cover: _text(doc['game_screenshot']).isEmpty ? null : _text(doc['game_screenshot']),
          areaName: doc['gameName']?.toString(),
          watching: _count(doc['game_total_count']),
          status: LiveStatus.live,
        ),
      );
    }
    return LivePage<LiveRoom>(items: rooms);
  }

  static List<Map<String, Object?>> _docs(Map<String, Object?> response, String key) {
    final section = response[key];
    final docs = section is Map<String, Object?> ? section['docs'] : null;
    return [
      for (final doc in docs is List ? docs : const <Object?>[])
        if (doc is Map<String, Object?>) doc,
    ];
  }

  /// A room id: numeric strings only, so advertisement entries — whose
  /// `profileRoom` is empty or a name — never become cards.
  static String? _numeric(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text) == null ? null : text;
  }

  /// A plain-text field, tolerating a missing one.
  static String _text(Object? value) => value?.toString() ?? '';

  /// A viewer count, which the directory sends as a *string* and the search
  /// results as a number — casting to `num?` (as this used to) threw on the
  /// directory and silently lost every room behind the first one.
  static int? _count(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }

  /// A title from the richer field, falling back to the shorter one.
  static String _title(Object? primary, Object? fallback) {
    final text = primary?.toString().trim() ?? '';
    return text.isNotEmpty ? text : (_text(fallback).trim());
  }

  static Map<String, Object?> _decode(String blob) {
    final cleaned = blob.replaceAll(_scriptEscape, '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('huya: page config is not an object');
    }
    return decoded;
  }
}
