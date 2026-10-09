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
// quality/line selection - anonymous HLS only, which is what the feed-to-room
// chain needs to be real end to end.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'huya_signing.dart';

/// The source id every huya row carries.
const String huyaSourceId = 'huya.live';

/// A desktop Chrome UA: the web endpoints answer to it without a login.
const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36';

const Map<String, String> _webHeaders = <String, String>{
  'user-agent': _userAgent,
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// Extracts an int-like field that Huya returns sometimes as int, sometimes as string.
int _asInt(Object? value) => int.tryParse('$value') ?? 0;

/// The Huya source. One [NetworkClient] for the process the source lives in; the
/// source owns it and closes it in [dispose].
final class HuyaSource implements FeedCapability, BrowseCapability, SearchCapability, ResolveCapability {
  HuyaSource({NetworkClient? client}) : _client = client ?? NetworkClient();

  final NetworkClient _client;

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
    for (final (bussType, groupName) in topGroups) {
      tree.add(ContentCategory(id: bussType, name: groupName));
      try {
        final result = await _client.getJson(
          'https://live.cdn.huya.com/liveconfig/game/bussLive',
          headers: <String, String>{'user-agent': _userAgent},
          queryParameters: <String, Object?>{'bussType': bussType},
        );
        final rows = result['data'] as List?;
        if (rows == null) {
          continue;
        }
        for (final row in rows) {
          if (row is! Map) {
            continue;
          }
          final gid = _gid(row['gid']);
          if (gid.isEmpty) {
            continue;
          }
          tree.add(
            ContentCategory(
              id: gid,
              name: '${row['gameFullName'] ?? ''}',
              parentId: bussType,
              icon: 'https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg',
            ),
          );
        }
      } on FormatException {
        // One group failing to answer keeps its node and the rest of the
        // tree; a category browser with three of four groups beats none.
      }
    }
    _categoryTree = tree;
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
    final data = result['data'] as Map<String, Object?>?;
    final rows = data?['datas'] as List?;
    if (data == null || rows == null) {
      throw FormatException('Huya room list answered without data.datas (page ${page.page})');
    }
    final items = <ContentSummary>[for (final row in rows) _summaryFromListRow(row! as Map<String, Object?>)];
    final hasMore = _asInt(data['page']) < _asInt(data['totalPage']);
    return PageResult<ContentSummary>(items: items, page: page.page, pageSize: page.pageSize, hasMore: hasMore);
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final data = await _profileRoom(ref.contentId);
    final liveData = data?['liveData'] as Map<String, Object?>?;
    final introduction = '${liveData?['introduction'] ?? ''}';
    return ContentDetail(
      summary: ContentSummary(
        ref: ref,
        title: introduction.isNotEmpty ? introduction : '${liveData?['sRoomName'] ?? ref.contentId}',
        subtitle: '${liveData?['nick'] ?? ''}',
        cover: liveData?['screenshot']?.toString(),
        metadata: ContentMetadata(popularity: _asInt(liveData?['userCount'])),
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
      headers: <String, String>{'user-agent': _userAgent},
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
    final docs = ((result['response'] as Map<String, Object?>?)?['3'] as Map<String, Object?>?)?['docs'] as List?;
    final items = <ContentSummary>[
      if (docs != null)
        for (final doc in docs) _summaryFromSearchRow(doc! as Map<String, Object?>),
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: pageSize,
      hasMore: docs != null && items.length >= pageSize,
    );
  }

  ContentSummary _summaryFromSearchRow(Map<String, Object?> row) {
    var cover = '${row['game_screenshot'] ?? ''}';
    if (cover.isNotEmpty && !cover.contains('?')) {
      cover += '?x-oss-process=style/w338_h190&';
    }
    final title = '${row['game_introduction'] ?? ''}';
    final nick = '${row['game_nick'] ?? ''}';
    final area = '${row['gameName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['room_id'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['game_roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : row['game_imgUrl']?.toString(),
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
    if (result['status'] != 200) {
      throw StateError('Huya room $roomId answered status ${result['status']}');
    }
    return result['data'] as Map<String, Object?>?;
  }

  ContentSummary _summaryFromListRow(Map<String, Object?> row) {
    var cover = '${row['screenshot'] ?? ''}';
    if (cover.isNotEmpty && !cover.contains('?')) {
      cover += '?x-oss-process=style/w338_h190&';
    }
    final title = '${row['introduction'] ?? ''}';
    final nick = '${row['nick'] ?? ''}';
    final area = '${row['gameFullName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['profileRoom'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : null,
      metadata: ContentMetadata(popularity: _asInt(row['totalCount'])),
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final data = await _profileRoom(ref.contentId);
    final stream = data?['stream'] as Map<String, Object?>?;
    final bases = stream?['baseSteamInfoList'] as List?;
    if (stream == null || bases == null || bases.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // First usable base entry: each one carries the same stream on a different
    // CDN; line selection is a later slice, so the first entry is the line.
    final Map<String, Object?> entry = bases.first! as Map<String, Object?>;
    final streamName = '${entry['sStreamName'] ?? ''}';
    final flvBase = '${entry['sFlvUrl'] ?? ''}';
    if (streamName.isEmpty || flvBase.isEmpty) {
      throw StateError('Huya room ${ref.contentId} carries no usable stream entry');
    }
    final antiCode = '${entry['sHlsAntiCode'] ?? entry['sFlvAntiCode'] ?? ''}';
    final signed = buildAntiCode(streamName, createFallbackViewerUid(), antiCode);
    final uri = Uri.parse('${flvBase.replaceFirst('flv', 'hls')}/$streamName.m3u8?$signed&codec=264');

    final liveData = data?['liveData'] as Map<String, Object?>?;
    return MediaTicket(
      id: '$huyaSourceId/${ref.contentId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: DateTime.now().toUtc(),
      headers: const <String, String>{'user-agent': _userAgent, 'referer': 'https://www.huya.com/'},
      // The anti-code lease is minutes long; a hard deadline would be a guess
      // at which minute, and the contract makes expiresAt the prefetch trigger.
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: MediaPlaybackMetadata(
        title: '${liveData?['introduction'] ?? liveData?['sRoomName'] ?? ref.contentId}',
        artist: '${liveData?['nick'] ?? ''}',
        isLive: true,
        extra: <String, Object?>{if (liveData?['screenshot'] != null) 'cover': liveData!['screenshot']},
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) {
    // The ticket id is the room: re-running resolve for the same ref is exactly
    // what a fresh lease is, and no state lives in this source to preserve.
    final roomId = expired.id.startsWith('$huyaSourceId/') ? expired.id.substring(huyaSourceId.length + 1) : '';
    if (roomId.isEmpty) {
      throw StateError('Huya ticket ${expired.id} does not name a room');
    }
    return resolve(ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom));
  }
}
