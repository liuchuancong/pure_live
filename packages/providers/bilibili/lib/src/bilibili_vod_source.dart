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
//
// What a response's `code` means here: 0 is data, anything else is the site refusing (risk control, -403 for
// a guest asking for what only an account may see, -352 when the buvid3 cookie did not pass). Every entry
// point checks it, because a refusal decoded as an empty list looks to the viewer like a site with nothing on
// it, and the recovery ladder has nothing to retry on.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock;

import 'bili_wbi.dart';

/// The source id every bilibili vod row carries.
const String bilibiliSourceId = 'bilibili.vod';

/// The one listing category this source serves.
const String bilibiliPopularCategory = 'popular';

/// The metadata key a page's cid travels under, in an episode ref and in a ticket alike.
const String bilibiliCidKey = 'bilibili.cid';

/// The metadata key holding the bvid an episode ticket was minted for.
const String bilibiliBvidKey = 'bilibili.bvid';

const Map<String, String> _htmlEntities = <String, String>{
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&nbsp;': ' ',
  '&#39;': "'",
};

Map<String, String> _webHeaders({required String buvid3}) => <String, String>{
  'user-agent': biliUserAgent,
  'referer': 'https://www.bilibili.com/',
  'cookie': 'buvid3=$buvid3',
};

/// Strips the `<em class="keyword">` highlighting search answers wrap titles in, and the entities inside them.
///
/// The entities are not decoration: search returns `&quot;` in the highlighted span routinely, and a row that
/// renders `&quot;` in the list is a row the viewer reads as broken.
String _cleanTitle(String raw) {
  final stripped = raw.replaceAll(RegExp(r'</?em[^>]*>'), '');
  var text = stripped;
  _htmlEntities.forEach((String entity, String value) {
    text = text.replaceAll(entity, value);
  });
  return text.trim();
}

/// The Bilibili vod source. One transport per source instance.
final class BilibiliVodSource implements BrowseCapability, SearchCapability, ResolveCapability {
  /// One [NetworkClient] is shared with the signer: passing none used to build a second one inside
  /// `BiliWbiSigner`, which [dispose] never closed, so every constructed source leaked a dio instance and its
  /// connection pool.
  BilibiliVodSource({NetworkClient? client, Clock? clock})
    : _client = client ?? NetworkClient(),
      buvid3 = randomBuvid3() {
    _wbi = BiliWbiSigner(client: _client, clock: clock);
  }

  final NetworkClient _client;
  late final BiliWbiSigner _wbi;

  /// Issued once per source: web api ties search access to this cookie.
  final String buvid3;

  void dispose() => _client.close();

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[
    ContentCategory(id: bilibiliPopularCategory, name: '热门'),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    // One servable category today: the popular table. Page numbers map straight onto the endpoint's pn.
    final category = query.category;
    if (category != null && category != bilibiliPopularCategory) {
      throw StateError('$bilibiliSourceId has no category "$category"; it lists only $bilibiliPopularCategory');
    }
    final page = query.page;
    final result = await _json('https://api.bilibili.com/x/web-interface/popular', <String, Object?>{
      'pn': page.page,
      'ps': page.pageSize,
    }, 'popular');
    final list = _asList(result['data'] is Map ? (result['data']! as Map)['list'] : null);
    final items = <ContentSummary>[
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
    final owner = row['owner'] is Map ? Map<String, Object?>.from(row['owner']! as Map) : const <String, Object?>{};
    final stat = row['stat'] is Map ? Map<String, Object?>.from(row['stat']! as Map) : const <String, Object?>{};
    return ContentSummary(
      ref: ContentRef(sourceId: bilibiliSourceId, contentId: '${row['bvid'] ?? ''}', kind: ContentKind.vod),
      title: _cleanTitle('${row['title'] ?? ''}'),
      subtitle: '${owner['name'] ?? ''}',
      cover: _https('${row['pic'] ?? ''}'),
      metadata: ContentMetadata(popularity: _int(stat['view'])),
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final result = await _json('https://api.bilibili.com/x/web-interface/view', <String, Object?>{
      'bvid': ref.contentId,
    }, 'view ${ref.contentId}');
    final data = result['data'] is Map ? Map<String, Object?>.from(result['data']! as Map) : const <String, Object?>{};
    final owner = data['owner'] is Map ? Map<String, Object?>.from(data['owner']! as Map) : const <String, Object?>{};
    final stat = data['stat'] is Map ? Map<String, Object?>.from(data['stat']! as Map) : const <String, Object?>{};
    final pages = _asList(data['pages']);
    final summary = ContentSummary(
      ref: ref,
      title: _cleanTitle('${data['title'] ?? ''}'),
      subtitle: '${owner['name'] ?? ''}',
      cover: _https('${data['pic'] ?? ''}'),
      metadata: ContentMetadata(
        duration: _int(data['duration']) == null ? null : Duration(seconds: _int(data['duration'])!),
        popularity: _int(stat['view']),
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
                bilibiliCidKey: (pages[index]! as Map)['cid'],
                'part': (pages[index]! as Map)['part'],
                'page': index + 1,
              },
            ),
      ],
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    // Video search sits on a wbi endpoint and needs the buvid3 cookie; the signed string is assembled here and
    // sent verbatim, because re-encoding it downstream would not be what was hashed.
    final signed = await _wbi.signedQuery(<String, String>{
      'search_type': 'video',
      'keyword': query.keyword,
      'page': '${query.page.page}',
      'page_size': '${query.page.pageSize.clamp(1, 50)}',
    });
    final result = await _json(
      'https://api.bilibili.com/x/web-interface/search/type?$signed',
      null,
      'search "${query.keyword}"',
    );
    final data = result['data'] is Map ? Map<String, Object?>.from(result['data']! as Map) : const <String, Object?>{};
    final rows = _asList(data['result']);
    final items = <ContentSummary>[
      for (final row in rows)
        if (row is Map)
          ContentSummary(
            ref: ContentRef(sourceId: bilibiliSourceId, contentId: '${row['bvid'] ?? ''}', kind: ContentKind.vod),
            title: _cleanTitle('${row['title'] ?? ''}'),
            subtitle: '${row['author'] ?? ''}',
            cover: _https('${row['pic'] ?? ''}'),
            metadata: ContentMetadata(
              duration: _parseDuration('${row['duration'] ?? ''}'),
              popularity: _int(row['play']),
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

  /// Search answers durations as "mm:ss" text; anything unparseable is "the site did not say", not zero.
  ///
  /// The first version replaced an unparseable part with 0, so an empty field became a 0-second video and a
  /// surface showed "00:00" as a fact about the row.
  static Duration? _parseDuration(String text) {
    final parts = text.trim().split(':');
    if (parts.isEmpty || parts.first.isEmpty) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      final value = int.tryParse(part.trim());
      if (value == null || value < 0) {
        return null;
      }
      seconds = seconds * 60 + value;
    }
    return Duration(seconds: seconds);
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final bvid = ref.parentId ?? ref.contentId;
    final cid = _int(ref.metadata[bilibiliCidKey]);
    if (cid == null) {
      throw StateError('Bilibili episode ${ref.contentId} carries no cid, so no page can be played');
    }
    if (line != null) {
      // One guest stream per page: there is no second CDN to name, so a line request is refused rather than
      // quietly played as the one that exists.
      throw StateError('$bilibiliSourceId serves one guest stream per page; line ${line.id} does not exist');
    }
    // The guest path: platform=oc plus try_look=1 lets an anonymous viewer
    // open the stream at capped quality; fnval=1 keeps the answer a durl mp4
    // list rather than a dash manifest, which the kernel plays as-is.
    final result = await _json('https://api.bilibili.com/x/player/playurl', <String, Object?>{
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
    }, 'playurl $bvid#$cid');
    final data = result['data'] is Map ? Map<String, Object?>.from(result['data']! as Map) : const <String, Object?>{};
    final durl = _asList(data['durl']);
    if (durl.isEmpty || durl.first is! Map) {
      throw StateError('Bilibili playurl answered no durl for $bvid#$cid (guest stream unavailable)');
    }
    final first = Map<String, Object?>.from(durl.first! as Map);
    final url = '${first['url'] ?? ''}';
    if (url.isEmpty) {
      throw StateError('Bilibili playurl answered an empty url for $bvid#$cid');
    }
    final requested = quality?.id;
    return MediaTicket(
      id: '$bilibiliSourceId/$bvid/${ref.contentId}',
      uri: Uri.parse(url),
      kind: MediaKind.vod,
      protocol: MediaProtocol.https,
      createdAt: DateTime.now().toUtc(),
      // Bilibili cdn urls answer only to a bilibili referer; without it the
      // download 403s no matter how valid the url is.
      headers: <String, String>{'user-agent': biliUserAgent, 'referer': 'https://www.bilibili.com/'},
      refresh: const MediaTicketRefreshInfo(supported: true),
      metadata: MediaPlaybackMetadata(
        isLive: false,
        duration: _int(first['length']) == null ? null : Duration(seconds: _int(first['length'])!),
        extra: <String, Object?>{
          bilibiliBvidKey: bvid,
          bilibiliCidKey: cid,
          // Echoed so a surface can show what was asked against what a guest is allowed to get: try_look caps
          // the bitrate, and silently dropping the request is how "I chose 1080p" becomes "it played 480p".
          if (requested != null) 'bilibili.requestedQuality': requested,
          if (first['size'] is num) 'bilibili.sizeBytes': first['size'],
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // Play urls are short-lived and cheap to re-mint: a fresh resolve of the same episode is exactly what a
    // refresh is here. The cid travels in the ticket's own metadata, so this survives the resolve-time cache
    // being gone - and there is no cache to grow without bound any more.
    final bvid = expired.metadata.extra[bilibiliBvidKey];
    final cid = expired.metadata.extra[bilibiliCidKey];
    if (bvid is! String || cid is! num) {
      throw StateError('Bilibili ticket ${expired.id} carries no bvid/cid, so it cannot be re-minted');
    }
    // The episode's own id is the last leg of the ticket id (`source/bvid/content`); a ticket that does not
    // have that shape still replays the video, because bvid+cid is what playurl needs.
    final legs = expired.id.split('/');
    final contentId = legs.length == 3 ? legs.last : bvid;
    return resolve(
      ContentRef(
        sourceId: bilibiliSourceId,
        contentId: contentId,
        kind: ContentKind.episode,
        parentId: bvid,
        metadata: <String, Object?>{bilibiliCidKey: cid},
      ),
    );
  }

  Future<Map<String, Object?>> _json(String url, Map<String, Object?>? query, String what) async {
    final response = await _client.getJson(
      url,
      headers: _webHeaders(buvid3: buvid3),
      queryParameters: query,
    );
    final code = response['code'];
    if (code != 0) {
      // The site's own message is in the answer; dropping it is why "search failed" is undiagnosable from a
      // log line three weeks later.
      throw StateError(
        'Bilibili $what answered code $code${response['message'] is String ? ': ${response['message']}' : ''}',
      );
    }
    return response;
  }

  static List<Object?> _asList(Object? value) => value is List ? value : const <Object>[];

  static int? _int(Object? value) => value is num ? value.toInt() : (value is String ? int.tryParse(value) : null);

  /// Bilibili serves covers over http on the same host; a webview refuses to load them from an https page.
  static String _https(String url) => url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
}
