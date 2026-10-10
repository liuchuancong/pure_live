// Module: lib/src/huya_source.dart
// Purpose: The Huya live source: recommend feed and HLS resolve over the public web endpoints.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: endpoint knowledge follows the v1-maintained huya line
// (origin/master lib/shared/platforms/huya/huya_site.dart, itself synced from
// dart_simple_live). This is a fresh implementation against the capability
// contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Deliberately smaller than
// the v1 line for this first slice: no login cookies, no TARS token lease, no
// quality selection - anonymous HLS only, which is what the feed-to-room
// chain needs to be real end to end.
//
// Shape rule for this file: the endpoints are somebody else's, and they have returned the same field as a map,
// a number and a string in the past. Nothing casts a response field it has not checked - `row! as Map` on a
// list page used to throw on the first row that came back differently, and one odd row lost the whole page.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'huya_signing.dart';

/// The source id every huya row carries.
const String huyaSourceId = 'huya.live';

/// The metadata key naming the CDN entry a ticket was opened from, 1-based as a surface shows it.
const String huyaLineKey = 'huya.line';

/// The metadata key holding how many CDN entries the room offered at resolve time.
const String huyaLineCountKey = 'huya.lineCount';

/// A desktop Chrome UA: the web endpoints answer to it without a login.
const String huyaUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36';

const Map<String, String> _webHeaders = <String, String>{
  'user-agent': huyaUserAgent,
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// The OSS thumbnail suffix the web list asks the CDN for; the raw screenshot is several times larger.
const String _coverThumbQuery = '?x-oss-process=style/w338_h190&';

Map<String, Object?>? _asMap(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

List<Object?> _asList(Object? value) => value is List ? value : const <Object?>[];

/// A number the endpoint might have sent as a num or as a numeric string; null when it is neither.
int? _intOrNull(Object? value) => switch (value) {
  null => null,
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  final Map<Object?, Object?> map => _intOrNull(map['value']),
  _ => null,
};

/// The Huya source. One [NetworkClient] for the process the source lives in; the
/// source owns it and closes it in [dispose].
final class HuyaSource implements FeedCapability, BrowseCapability, SearchCapability, ResolveCapability {
  HuyaSource({NetworkClient? client, Clock? clock})
    : _client = client ?? NetworkClient(),
      _clock = clock ?? systemClock;

  final NetworkClient _client;
  final Clock _clock;

  /// Releases the source's own transport. Tickets already handed out stay
  /// valid until their own lease ends; nothing here can shorten them.
  void dispose() => _client.close();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _listRooms(const <String, Object?>{}, page);

  /// The parsed category table, cached for the process: the config endpoint
  /// is small and changes rarely.
  List<ContentCategory>? _categoryTree;

  @override
  Future<List<ContentCategory>> categories() async {
    final cached = _categoryTree;
    if (cached != null) {
      return cached;
    }
    // Four top groups, the ids the web config has always used; each answer's
    // gid field has shipped in four historical shapes (map / double / int /
    // string), so the parse converges every shape instead of trusting one.
    const topGroups = <(String, String)>[('1', '网游'), ('2', '单机'), ('8', '娱乐'), ('3', '手游')];
    final tree = <ContentCategory>[];
    var complete = true;
    for (final (bussType, groupName) in topGroups) {
      tree.add(ContentCategory(id: bussType, name: groupName));
      try {
        final result = await _client.getJson(
          'https://live.cdn.huya.com/liveconfig/game/bussLive',
          headers: <String, String>{'user-agent': huyaUserAgent},
          queryParameters: <String, Object?>{'bussType': bussType},
        );
        for (final row in _asList(result['data'])) {
          final game = _asMap(row);
          if (game == null) {
            continue;
          }
          final gid = _gid(game['gid']);
          if (gid.isEmpty) {
            continue;
          }
          tree.add(
            ContentCategory(
              id: gid,
              name: '${game['gameFullName'] ?? ''}',
              parentId: bussType,
              icon: 'https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg',
            ),
          );
        }
      } on Object {
        // One group failing to answer keeps its node and the rest of the tree; a category browser with three
        // of four groups beats none. `on Object`, not `on FormatException`: a refused socket or a non-JSON
        // body is the ordinary way one group fails, and it used to end the whole call.
        complete = false;
      }
    }
    // A partial tree is not cached: the first outage would otherwise pin three groups for the life of the
    // process, and the fourth would never come back without a restart.
    if (complete) {
      _categoryTree = tree;
    }
    return tree;
  }

  /// Converges the four historical gid shapes to one string.
  static String _gid(Object? raw) {
    if (raw is Map) {
      return '${raw['value'] ?? ''}'.split(',').first.trim();
    }
    if (raw is num) {
      return raw.toInt().toString();
    }
    return '${raw ?? ''}'.trim();
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) {
    // An empty category is the home listing, which for huya is the recommend
    // feed; a named category is its game id from the category tree.
    final category = query.category;
    if (category == null || category.isEmpty) {
      return feed(query.page);
    }
    return _listRooms(<String, Object?>{'gameId': category}, query.page);
  }

  /// One page of the web room list, named by optional game id.
  Future<PageResult<ContentSummary>> _listRooms(Map<String, Object?> extra, PageRequest page) async {
    final result = await _client.getJson(
      'https://www.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{
        'm': 'LiveList',
        'do': 'getLiveListByPage',
        'tagAll': 0,
        ...extra,
        'page': page.page,
      },
    );
    final data = _asMap(result['data']);
    if (data == null || !data.containsKey('datas')) {
      throw FormatException('Huya room list answered without data.datas (page ${page.page})');
    }
    final rows = _asList(data['datas']);
    // An empty `datas` on the last page is a real answer, not a broken one; refusing it would make the pager
    // treat the end of the list as a failure.
    final items = <ContentSummary>[
      for (final row in rows)
        if (_asMap(row) case final Map<String, Object?> game) _summaryFromListRow(game),
    ];
    final answeredPage = _intOrNull(data['page']) ?? page.page;
    final totalPage = _intOrNull(data['totalPage']);
    return PageResult<ContentSummary>(
      items: items,
      page: page.page,
      pageSize: page.pageSize,
      // Without totalPage the endpoint gave no end signal at all; claiming "there is more" would page forever.
      hasMore: totalPage == null ? false : answeredPage < totalPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final data = await _profileRoom(ref.contentId);
    final liveData = _asMap(data?['liveData']);
    final introduction = '${liveData?['introduction'] ?? ''}';
    return ContentDetail(
      summary: ContentSummary(
        ref: ref,
        title: introduction.isNotEmpty ? introduction : '${liveData?['sRoomName'] ?? ref.contentId}',
        subtitle: '${liveData?['nick'] ?? ''}',
        cover: liveData?['screenshot']?.toString(),
        metadata: ContentMetadata(popularity: _intOrNull(liveData?['userCount'])),
      ),
      description: introduction,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    // Rows here are capped at 50 and paging runs through start, so hasMore is
    // "this page came back full", the only signal the endpoint gives.
    final pageSize = query.page.pageSize.clamp(1, 50);
    final result = await _client.getJson(
      'https://search.cdn.huya.com/',
      headers: <String, String>{'user-agent': huyaUserAgent},
      queryParameters: <String, Object?>{
        'm': 'Search',
        'do': 'getSearchContent',
        'q': query.keyword,
        'uid': 0,
        'v': 4,
        'typ': -5,
        'livestate': 0,
        'rows': pageSize,
        'start': (query.page.page - 1) * pageSize,
      },
    );
    final docs = _asList(_asMap(_asMap(result['response'])?['3'])?['docs']);
    final items = <ContentSummary>[
      for (final doc in docs)
        if (_asMap(doc) case final Map<String, Object?> row) _summaryFromSearchRow(row),
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: pageSize,
      hasMore: docs.isNotEmpty && items.length >= pageSize,
    );
  }

  ContentSummary _summaryFromSearchRow(Map<String, Object?> row) {
    final cover = _thumb('${row['game_screenshot'] ?? ''}');
    final title = '${row['game_introduction'] ?? ''}';
    final nick = '${row['game_nick'] ?? ''}';
    final area = '${row['gameName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['room_id'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['game_roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : row['game_imgUrl']?.toString(),
      metadata: ContentMetadata(popularity: _intOrNull(row['game_onlineCount'])),
    );
  }

  /// The profileRoom document for one room. Shared by resolve and detail: it
  /// is the one endpoint that describes a room fully.
  Future<Map<String, Object?>?> _profileRoom(String roomId) async {
    final result = await _client.getJson(
      'https://mp.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{'m': 'Live', 'do': 'profileRoom', 'roomid': roomId, 'showSecret': '1'},
    );
    if ('${result['status']}' != '200') {
      // A room that does not exist and a room that is closed both answer here; the message says which.
      throw StateError(
        'Huya room $roomId answered status ${result['status']}'
        '${result['message'] is String ? ': ${result['message']}' : ''}',
      );
    }
    return _asMap(result['data']);
  }

  ContentSummary _summaryFromListRow(Map<String, Object?> row) {
    final cover = _thumb('${row['screenshot'] ?? ''}');
    final title = '${row['introduction'] ?? ''}';
    final nick = '${row['nick'] ?? ''}';
    final area = '${row['gameFullName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['profileRoom'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : null,
      metadata: ContentMetadata(popularity: _intOrNull(row['totalCount'])),
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final data = await _profileRoom(ref.contentId);
    final stream = _asMap(data?['stream']);
    final bases = _asList(stream?['baseSteamInfoList']);
    if (stream == null || bases.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // Each entry is the same stream on a different CDN, so a line is an ordinal. A name the source never gave
    // is refused rather than played as entry one: silently switching CDN is how "this line is broken" turns
    // into "the picture is broken on every line".
    final wanted = _lineIndex(line, bases.length);
    final entry = _asMap(bases[wanted]) ?? const <String, Object?>{};

    final streamName = '${entry['sStreamName'] ?? ''}';
    final hlsBase = '${entry['sHlsUrl'] ?? ''}';
    final flvBase = '${entry['sFlvUrl'] ?? ''}';
    // The endpoint ships both urls. Rewriting the flv host into an hls one is the last resort, not the plan:
    // the two live on different hosts for some CDNs, and replaceFirst('flv','hls') rewrites the first 'flv'
    // it finds anywhere in the string - including one inside a path segment.
    final base = hlsBase.isNotEmpty ? hlsBase : flvBase.replaceFirst('flv', 'hls');
    if (streamName.isEmpty || base.isEmpty) {
      throw StateError('Huya room ${ref.contentId} carries no usable stream entry');
    }
    // The suffix is the server's, not a guess - but only for the url it was describing. Falling back to the
    // flv base while keeping `.flv` would hand the player a different protocol than the ticket declares.
    final container = hlsBase.isNotEmpty && entry['sHlsUrlSuffix'] is String && '${entry['sHlsUrlSuffix']}'.isNotEmpty
        ? '${entry['sHlsUrlSuffix']}'
        : 'm3u8';
    final antiCode = '${entry['sHlsAntiCode'] ?? entry['sFlvAntiCode'] ?? ''}';
    final signed = buildAntiCode(streamName, createFallbackViewerUid(), antiCode, now: _clock());
    final query = signed.isEmpty ? 'codec=264' : '$signed&codec=264';
    final uri = Uri.parse('${_trimSlash('$base')}/$streamName.$container?$query');

    final liveData = _asMap(data?['liveData']);
    return MediaTicket(
      id: '$huyaSourceId/${ref.contentId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: const <String, String>{'user-agent': huyaUserAgent, 'referer': 'https://www.huya.com/'},
      // The anti-code lease is minutes long; a hard deadline would be a guess
      // at which minute, and the contract makes expiresAt the prefetch trigger.
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: MediaPlaybackMetadata(
        title: '${liveData?['introduction'] ?? liveData?['sRoomName'] ?? ref.contentId}',
        artist: '${liveData?['nick'] ?? ''}',
        isLive: true,
        extra: <String, Object?>{
          if (liveData?['screenshot'] != null) 'cover': liveData!['screenshot'],
          huyaLineKey: wanted + 1,
          huyaLineCountKey: bases.length,
          // A quality ask is recorded, not honoured: this slice serves the anonymous stream, and a surface
          // that asked for 1080p and got the capped one has to be able to say so.
          if (quality != null) 'huya.requestedQuality': quality.id,
        },
      ),
    );
  }

  /// [line] selects a CDN entry by its 1-based ordinal; anything else is refused.
  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'Huya offers $available CDN line(s); line "${line.id}" is not one of them '
        '(they are named by their 1-based position, not by a label)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // The ticket id is the room: re-running resolve for the same ref is exactly
    // what a fresh lease is, and no state lives in this source to preserve.
    // The line the viewer was on travels in the ticket, so a refresh on line 3 does not move them to line 1.
    final roomId = expired.id.startsWith('$huyaSourceId/') ? expired.id.substring(huyaSourceId.length + 1) : '';
    if (roomId.isEmpty) {
      throw StateError('Huya ticket ${expired.id} does not name a room');
    }
    final line = _intOrNull(expired.metadata.extra[huyaLineKey]);
    return resolve(
      ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom),
      line: line == null ? null : SelectionRef('$line'),
      quality: expired.metadata.extra['huya.requestedQuality'] is String
          ? SelectionRef(expired.metadata.extra['huya.requestedQuality']! as String)
          : null,
    );
  }

  static String _thumb(String cover) {
    if (cover.isEmpty || cover.contains('?')) {
      return cover;
    }
    return '$cover$_coverThumbQuery';
  }

  static String _trimSlash(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
