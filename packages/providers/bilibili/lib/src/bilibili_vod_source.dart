// Module: lib/src/bilibili_vod_source.dart
// Purpose: The Bilibili vod source: popular listing, WBI-signed search, video
// detail with pages, and guest playback.
// Author: liuchuancong
// Created: 2026-10-09
//
// Provenance: endpoint knowledge follows the newBV bilibili-api client
// (web-interface/popular, web-interface/view, player/playurl with the guest
// try_look path) and the v1-maintained WBI recipe. Fresh implementation
// against the capability contracts - no upstream file or commit enters
// through this (UPSTREAM_REVIEW_POLICY.md).
//
// Deliberately small first slice: no login, no大会员 quality, no pgc/bangumi,
// no danmaku. Guests get the try_look stream (capped quality); auth is its
// own wave.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'bili_wbi.dart';

/// The source id every bilibili vod row carries.
const String bilibiliSourceId = 'bilibili.vod';

const String _ua = biliUserAgent;

Map<String, String> _webHeaders({String? buvid3}) => <String, String>{
  'user-agent': _ua,
  'referer': 'https://www.bilibili.com/',
  if (buvid3 != null) 'cookie': 'buvid3=$buvid3',
};

/// Strips the <em class="keyword"> highlighting search answers wrap titles in.
String _cleanTitle(String raw) => raw.replaceAll(RegExp(r'</?em[^>]*>'), '');

/// The Bilibili vod source. One transport per source instance.
final class BilibiliVodSource implements BrowseCapability, SearchCapability, ResolveCapability {
  BilibiliVodSource({NetworkClient? client})
    : _client = client ?? NetworkClient(),
      _wbi = BiliWbiSigner(client: client),
      buvid3 = randomBuvid3();

  final NetworkClient _client;
  final BiliWbiSigner _wbi;

  /// Issued once per source: web api ties search access to this cookie.
  final String buvid3;

  /// The cid each resolved episode used. The ticket id names the episode but
  /// cannot carry the cid, and refresh needs exactly that number.
  final Map<String, int> _resolvedCids = <String, int>{};

  void dispose() => _client.close();

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[
    ContentCategory(id: 'popular', name: '热门'),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    // One servable category today: the popular table. Page numbers map
    // straight onto the endpoint's pn.
    final page = query.page;
    final result = await _client.getJson(
      'https://api.bilibili.com/x/web-interface/popular',
      headers: _webHeaders(buvid3: buvid3),
      queryParameters: <String, Object?>{'pn': page.page, 'ps': page.pageSize},
    );
    final list = ((result['data'] ?? const <String, Object?>{}) as Map<String, Object?>)['list'] as List?;
    final items = <ContentSummary>[
      if (list != null)
        for (final row in list)
          if (row is Map) _summaryFromCard(Map<String, Object?>.from(row)),
    ];
    // The popular table keeps a full page when more exist; a short page is the
    // only end signal it gives.
    return PageResult<ContentSummary>(
      items: items,
      page: page.page,
      pageSize: page.pageSize,
      hasMore: items.length >= page.pageSize,
      mode: PageMode.fixedPage,
    );
  }

  ContentSummary _summaryFromCard(Map<String, Object?> row) {
    final owner = row['owner'] is Map ? Map<String, Object?>.from(row['owner'] as Map) : const <String, Object?>{};
    final stat = row['stat'] is Map ? Map<String, Object?>.from(row['stat'] as Map) : const <String, Object?>{};
    return ContentSummary(
      ref: ContentRef(sourceId: bilibiliSourceId, contentId: '${row['bvid'] ?? ''}', kind: ContentKind.vod),
      title: '${row['title'] ?? ''}',
      subtitle: '${owner['name'] ?? ''}',
      cover: '${row['pic'] ?? ''}'.replaceFirst('http://', 'https://'),
      metadata: ContentMetadata(popularity: (stat['view'] is num) ? (stat['view']! as num).toInt() : null),
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final result = await _client.getJson(
      'https://api.bilibili.com/x/web-interface/view',
      headers: _webHeaders(buvid3: buvid3),
      queryParameters: <String, Object?>{'bvid': ref.contentId},
    );
    if (result['code'] != 0) {
      throw StateError('Bilibili view ${ref.contentId} answered code ${result['code']}');
    }
    final data = (result['data'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final pages = data['pages'] as List? ?? const [];
    final summary = ContentSummary(
      ref: ref,
      title: '${data['title'] ?? ''}',
      subtitle: ((data['owner'] ?? const <String, Object?>{}) as Map<String, Object?>)['name']?.toString(),
      cover: '${data['pic'] ?? ''}'.replaceFirst('http://', 'https://'),
      metadata: ContentMetadata(
        duration: (data['duration'] is num) ? Duration(seconds: (data['duration']! as num).toInt()) : null,
        popularity: ((data['stat'] ?? const <String, Object?>{}) as Map<String, Object?>)['view'] is num
            ? (((data['stat'])! as Map)['view']! as num).toInt()
            : null,
      ),
    );
    return ContentDetail(
      summary: summary,
      description: '${data['desc'] ?? ''}',
      // Every page is a playable child; its cid travels in ref metadata for
      // resolve, exactly like the spider adapter's episode coordinates.
      children: <ContentRef>[
        for (var index = 0; index < pages.length; index++)
          if (pages[index] is Map)
            ContentRef(
              sourceId: bilibiliSourceId,
              contentId: pages.length == 1 ? ref.contentId : '${ref.contentId} P${index + 1}',
              kind: ContentKind.episode,
              parentId: ref.contentId,
              metadata: <String, Object?>{
                'cid': (pages[index]! as Map)['cid'],
                'part': (pages[index]! as Map)['part'],
                'page': index + 1,
              },
            ),
      ],
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    // Video search sits on a wbi endpoint and needs the buvid3 cookie; both
    // are per-source state, so the signed query is assembled here.
    final signed = await _wbi.sign(<String, String>{
      'search_type': 'video',
      'keyword': query.keyword,
      'page': '${query.page.page}',
      'page_size': '${query.page.pageSize.clamp(1, 50)}',
    });
    final result = await _client.getJson(
      'https://api.bilibili.com/x/web-interface/search/type',
      headers: _webHeaders(buvid3: buvid3),
      queryParameters: <String, Object?>{...signed},
    );
    if (result['code'] != 0) {
      throw StateError('Bilibili search answered code ${result['code']}');
    }
    final data = (result['data'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final rows = data['result'] as List? ?? const [];
    final items = <ContentSummary>[
      for (final row in rows)
        if (row is Map)
          ContentSummary(
            ref: ContentRef(sourceId: bilibiliSourceId, contentId: '${row['bvid'] ?? ''}', kind: ContentKind.vod),
            title: _cleanTitle('${row['title'] ?? ''}'),
            subtitle: '${row['author'] ?? ''}',
            cover: '${row['pic'] ?? ''}'.replaceFirst('http://', 'https://'),
            metadata: ContentMetadata(
              duration: _parseDuration('${row['duration'] ?? ''}'),
              popularity: (row['play'] is num) ? (row['play']! as num).toInt() : null,
            ),
          ),
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: query.page.pageSize,
      hasMore: items.length >= query.page.pageSize,
      mode: PageMode.fixedPage,
    );
  }

  /// Search answers durations as "mm:ss" text.
  static Duration? _parseDuration(String text) {
    final parts = text.split(':').map((part) => int.tryParse(part) ?? 0).toList();
    if (parts.isEmpty || parts.any((part) => part < 0)) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + part;
    }
    return Duration(seconds: seconds);
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final bvid = ref.parentId ?? ref.contentId;
    final cid = (ref.metadata['cid'] as num?)?.toInt();
    if (cid == null) {
      throw StateError('Bilibili episode ${ref.contentId} carries no cid');
    }
    _resolvedCids[ref.contentId] = cid;
    // The guest path: platform=oc plus try_look=1 lets an anonymous viewer
    // open the stream at capped quality; fnval=1 keeps the answer a durl mp4
    // list rather than a dash manifest, which the kernel plays as-is.
    final result = await _client.getJson(
      'https://api.bilibili.com/x/player/playurl',
      headers: _webHeaders(buvid3: buvid3),
      queryParameters: <String, Object?>{
        'bvid': bvid,
        'cid': cid,
        'qn': 80,
        'fnval': 1,
        'fnver': 0,
        'fourk': 1,
        'otype': 'json',
        'platform': 'oc',
        'web_location': '1315873',
        'try_look': '1',
      },
    );
    if (result['code'] != 0) {
      throw StateError('Bilibili playurl answered code ${result['code']}');
    }
    final data = (result['data'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final durl = data['durl'] as List?;
    if (durl == null || durl.isEmpty || durl.first is! Map) {
      throw StateError('Bilibili playurl answered no durl (guest stream unavailable)');
    }
    final url = '${(durl.first! as Map)['url'] ?? ''}';
    if (url.isEmpty) {
      throw StateError('Bilibili playurl answered an empty url');
    }
    return MediaTicket(
      id: '$bilibiliSourceId/$bvid/${ref.contentId}',
      uri: Uri.parse(url),
      kind: MediaKind.vod,
      protocol: MediaProtocol.https,
      createdAt: DateTime.now().toUtc(),
      // Bilibili cdn urls answer only to a bilibili referer; without it the
      // download 403s no matter how valid the url is.
      headers: <String, String>{'user-agent': _ua, 'referer': 'https://www.bilibili.com/'},
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: const MediaPlaybackMetadata(isLive: false),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // Play urls are short-lived and cheap to re-mint: a fresh resolve of the
    // same episode is exactly what a refresh is here. The cid comes from the
    // resolve-time cache because the ticket cannot carry it.
    final segments = expired.id.split('/');
    if (segments.length != 3) {
      throw StateError('Bilibili ticket ${expired.id} is not an episode ticket');
    }
    final cid = _resolvedCids[segments[2]];
    if (cid == null) {
      throw StateError('Bilibili episode ${segments[2]} was never resolved here');
    }
    return resolve(
      ContentRef(
        sourceId: bilibiliSourceId,
        contentId: segments[2],
        kind: ContentKind.episode,
        parentId: segments[1],
        metadata: <String, Object?>{'cid': cid},
      ),
    );
  }
}
