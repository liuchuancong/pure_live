// Module: lib/src/huya/huya_site.dart
// Purpose: The Huya live source: feed, categories, search, room status, CDN lines and guest HLS resolve.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: endpoint knowledge follows the v1-maintained huya line
// (origin/master lib/shared/platforms/huya/huya_site.dart, itself synced from
// dart_simple_live). This is a fresh implementation against the capability
// contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Still no login, no TARS
// token lease, no danmaku: the anonymous surface only, which is what the
// feed-to-room chain needs to be real end to end.
//
// The second file of the site: huya_api.dart says what is asked, what it is signed with and what comes back, and
// this class only turns those answers into the platform's capability interfaces. It reads no JSON field itself.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';
import 'huya_api.dart';

/// The Huya source. One [NetworkClient] for the process the source lives in.
final class HuyaSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        LineCapability,
        QualityCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  HuyaSource({NetworkClient? client, Clock? clock})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock;

  final NetworkClient _client;
  final Clock _clock;

  /// True when this source built its own transport and therefore has to close it. A client handed in belongs to
  /// the composition root, and a source that closed it would take the other consumers' connections with it.
  final bool _ownsClient;

  /// Releases the source's own transport, if it owns one. Tickets already handed out stay valid until their
  /// own lease ends; nothing here can shorten them.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

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
    // Four top groups; each answer's gid field has shipped in four historical shapes (map / double / int /
    // string), so the parse converges every shape instead of trusting one.
    final tree = <ContentCategory>[];
    var complete = true;
    for (final (bussType, groupName) in huyaTopGroups) {
      tree.add(ContentCategory(id: bussType, name: groupName));
      try {
        final result = await _client.getJson(
          huyaGameConfigUrl,
          headers: <String, String>{'user-agent': huyaUserAgent},
          queryParameters: <String, Object?>{'bussType': bussType},
        );
        for (final row in jsonList(result['data'])) {
          final game = jsonMap(row);
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
      huyaListUrl,
      headers: huyaWebHeaders,
      queryParameters: <String, Object?>{
        'm': 'LiveList',
        'do': 'getLiveListByPage',
        'tagAll': 0,
        ...extra,
        'page': page.page,
      },
    );
    final data = jsonMap(result['data']);
    if (data == null || !data.containsKey('datas')) {
      throw FormatException('Huya room list answered without data.datas (page ${page.page})');
    }
    final rows = jsonList(data['datas']);
    // An empty `datas` on the last page is a real answer, not a broken one; refusing it would make the pager
    // treat the end of the list as a failure.
    final items = <ContentSummary>[
      for (final row in rows)
        if (jsonMap(row) case final Map<String, Object?> game) HuyaListRow.fromList(game).toSummary(),
    ];
    final answeredPage = jsonInt(data['page']) ?? page.page;
    final totalPage = jsonInt(data['totalPage']);
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
    final profile = await _profile(ref.contentId);
    final introduction = profile.introduction;
    return ContentDetail(
      summary: ContentSummary(
        ref: ref,
        title: introduction.isNotEmpty ? introduction : (profile.roomName.isEmpty ? ref.contentId : profile.roomName),
        subtitle: profile.anchorName,
        cover: profile.screenshot,
        metadata: ContentMetadata(popularity: profile.viewers),
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
      huyaSearchUrl,
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
    final docs = jsonList(jsonMap(jsonMap(result['response'])?['3'])?['docs']);
    final items = <ContentSummary>[
      for (final doc in docs)
        if (jsonMap(doc) case final Map<String, Object?> row) HuyaListRow.fromSearch(row).toSummary(),
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: pageSize,
      hasMore: docs.isNotEmpty && items.length >= pageSize,
    );
  }

  /// The lines one room is served from, as 1-based ordinals.
  ///
  /// Huya's CDN rows carry no names at all, so `label` stays null and the id is the position: inventing
  /// "线路2" here would put a platform label on a row the source never named, and the viewer's "line 3 is
  /// broken" would then mean two different things on the two sides.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final profile = await _profile(ref.contentId);
    return <StreamOption>[
      for (var index = 0; index < profile.entries.length; index++)
        StreamOption(
          id: '${index + 1}',
          kind: StreamOptionKind.line,
          isDefault: index == 0,
          available: profile.entries[index].isUsable,
        ),
    ];
  }

  /// Empty: the anonymous path serves one rate, and the account menu (`hint` / `rateArr`) is a later slice.
  ///
  /// Answering empty rather than inventing a list is the honest read - a picker with one option is worse than
  /// no picker, and a fake 1080p row would be a promise this transport cannot keep.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async => const <StreamOption>[];

  @override
  Future<LiveRoom> room(ContentRef ref) async => huyaLiveRoom(await _profile(ref.contentId));

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    final profile = await _profile(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: switch (profile.liveStatusCode) {
        1 => LiveRoomState.live,
        0 => LiveRoomState.ended,
        _ => LiveRoomState.unknown,
      },
      viewers: profile.viewers,
      title: profile.roomName.isEmpty ? null : profile.roomName,
      cover: profile.screenshot,
      anchorName: profile.anchorName.isEmpty ? null : profile.anchorName,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final profile = await _profile(ref.contentId);
    if (profile.entries.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // Each entry is the same stream on a different CDN, so a line is an ordinal. A name the source never gave
    // is refused rather than played as entry one: silently switching CDN is how "this line is broken" turns
    // into "the picture is broken on every line".
    final wanted = _lineIndex(line, profile.entries.length);
    final entry = profile.entries[wanted];
    if (!entry.isUsable) {
      throw StateError('Huya room ${ref.contentId} carries no usable stream entry');
    }

    // The server ships both urls. Rewriting the flv base into an hls one is the last resort, not the plan: the
    // two live on different hosts for some CDNs, and replaceFirst('flv','hls') rewrites the first 'flv' it
    // finds anywhere in the string - including one inside a path segment.
    final hlsBase = entry.hlsUrl ?? '';
    final base = hlsBase.isNotEmpty ? hlsBase : (entry.flvUrl ?? '').replaceFirst('flv', 'hls');
    if (base.isEmpty) {
      throw StateError('Huya room ${ref.contentId} carries no usable stream entry');
    }
    // The suffix is the server's, not a guess - but only for the url it described. Keeping `.flv` while opening
    // the flv base would hand the player a stream that is not the protocol the ticket declares.
    final container = hlsBase.isNotEmpty && entry.hlsSuffix != null ? entry.hlsSuffix! : 'm3u8';
    final antiCode = hlsBase.isNotEmpty ? entry.hlsAntiCode : entry.flvAntiCode;
    final signed = buildAntiCode(entry.streamName, createFallbackViewerUid(), antiCode, now: _clock());
    final query = signed.isEmpty ? 'codec=264' : '$signed&codec=264';
    final uri = Uri.parse('${_trimSlash('$base')}/${entry.streamName}.$container?$query');

    return MediaTicket(
      id: '$huyaSourceId/${ref.contentId}',
      uri: uri,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: const <String, String>{'user-agent': huyaUserAgent, 'referer': 'https://www.huya.com/'},
      // The anti-code lease is minutes long; a hard deadline would be a guess at which minute, and the
      // contract makes expiresAt the prefetch trigger. Huya's expiry does not end an established connection
      // (unlike douyu), so cutsConnection stays false and the replacement is prefetched, not spliced.
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: MediaPlaybackMetadata(
        title: profile.introduction.isNotEmpty ? profile.introduction : profile.roomName,
        artist: profile.anchorName,
        isLive: true,
        extra: <String, Object?>{
          if (profile.screenshot != null) 'cover': profile.screenshot,
          huyaLineKey: wanted + 1,
          huyaLineCountKey: profile.entries.length,
          // Echoed so a surface can show what was asked against what a guest is allowed to get: silently
          // dropping the request is how "I chose 1080p" becomes "it played 480p".
          if (quality != null) huyaRequestedQualityKey: quality.id,
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // The ticket id is the room: re-running resolve for the same ref is exactly what a fresh lease is, and no
    // state lives in this source to preserve. The line the viewer was on travels in the ticket, so a refresh
    // on line 3 does not move them to line 1.
    final roomId = expired.id.startsWith('$huyaSourceId/') ? expired.id.substring(huyaSourceId.length + 1) : '';
    if (roomId.isEmpty) {
      throw StateError('Huya ticket ${expired.id} does not name a room');
    }
    final line = jsonInt(expired.metadata.extra[huyaLineKey]);
    final requested = expired.metadata.extra[huyaRequestedQualityKey];
    return resolve(
      ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom),
      line: line == null ? null : SelectionRef('$line'),
      quality: requested is String ? SelectionRef(requested) : null,
    );
  }

  /// The profileRoom document for one room. Shared by detail, status and resolve: it is the one endpoint that
  /// describes a room fully.
  Future<HuyaRoomProfile> _profile(String roomId) async {
    final result = await _client.getJson(
      huyaProfileRoomUrl,
      headers: huyaWebHeaders,
      queryParameters: <String, Object?>{'m': 'Live', 'do': 'profileRoom', 'roomid': roomId, 'showSecret': '1'},
    );
    if ('${result['status']}' != '200') {
      // A room that does not exist and a room that is closed both answer here; the message says which.
      throw HuyaProfileRequestFailure(
        roomId,
        status: '${result['status'] ?? 'none'}',
        message: result['message'] is String ? result['message']! as String : null,
      );
    }
    return HuyaRoomProfile.fromJson(roomId, jsonMap(result['data']) ?? const <String, Object?>{});
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

  static String _trimSlash(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
