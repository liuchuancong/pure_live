// Module: lib/src/live/douyu_source.dart
// Purpose: The Douyu live source: recommend feed, category browse, search and the signed anonymous resolve.
// Author: liuchuancong
// Created: 2026-10-10
//
// Provenance: endpoints, row fields and the play-url ladder follow the v1-maintained Douyu line
// (origin/master lib/shared/platforms/douyu/douyu_site.dart). This is a fresh implementation against the v2
// capability contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Slice scope, deliberately smaller than v1:
// anonymous viewer only - no pasted login cookie, no danmaku socket, no quality or CDN line picking (rate -1
// lets the CDN choose), no super-chat. The chain this has to make real is feed -> room -> playable ticket.

import 'dart:convert';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../models/douyu_row.dart';
import 'douyu_sign.dart';

/// Why a Douyu call answered without what was asked for. Named rather than a bare StateError because the
/// player's recovery ladder and the room page both need to tell "this room is gone" from "the network failed".
final class DouyuApiException implements Exception {
  DouyuApiException(this.message, {this.errorCode, this.cause});

  final String message;

  /// Douyu's own `error` field, when the answer carried one.
  final int? errorCode;
  final Object? cause;

  @override
  String toString() {
    final code = errorCode == null ? '' : ' (error $errorCode)';
    final reason = cause == null ? '' : ': $cause';
    return 'DouyuApiException: $message$code$reason';
  }
}

/// How long a signed play url is worth prefetching for when the answer states no expiry of its own.
const Duration kDouyuPlayLeaseLead = Duration(seconds: 45);

const String _feedPath = 'https://www.douyu.com/japi/weblist/apinc/allpage/6';
const String _categoryTreePath = 'https://m.douyu.com/api/cate/list';
const String _directoryPath = 'https://www.douyu.com/gapi/rkc/directory/mixList';
const String _profilePath = 'https://www.douyu.com/betard';
const String _searchPath = 'https://www.douyu.com/japi/search/api/searchShow';
const String _playPath = 'https://www.douyu.com/lapi/live/getH5PlayV1';

/// The Douyu live source.
///
/// Owns its [NetworkClient] and closes it in [dispose], unless the caller passed one it wants to keep -
/// the same borrowing rule the extension transport follows.
final class DouyuSource implements FeedCapability, BrowseCapability, SearchCapability, ResolveCapability {
  DouyuSource({NetworkClient? client, DouyuDevice? device, Clock? clock})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _device = device ?? DouyuDevice(),
      _clock = clock ?? systemClock {
    _signer = DouyuSigner(client: _client, device: _device, clock: clock);
  }

  final NetworkClient _client;
  final bool _ownsClient;
  final DouyuDevice _device;
  final Clock _clock;
  late final DouyuSigner _signer;

  /// Releases the transport this source created. A borrowed client stays open for whoever lent it.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _roomList('$_feedPath/${page.page}', page);

  List<ContentCategory>? _categoryTree;

  @override
  Future<List<ContentCategory>> categories() async {
    final cached = _categoryTree;
    if (cached != null) {
      return cached;
    }
    final json = await _client.getJson(_categoryTreePath, headers: _device.headers());
    final data = json['data'];
    if (data is! Map) {
      throw DouyuApiException('category list answered without a data object');
    }
    final parents = data['cate1Info'];
    final children = data['cate2Info'];
    if (parents is! List || children is! List) {
      throw DouyuApiException('category list answered without cate1Info/cate2Info');
    }
    // The two arrays are joined by cate1Id: the endpoint returns the flat groups and the flat categories, and
    // a browser that wants a tree has to assemble it.
    final byParent = <String, List<Map<Object?, Object?>>>{};
    for (final child in children.whereType<Map<Object?, Object?>>()) {
      byParent.putIfAbsent('${child['cate1Id'] ?? ''}', () => <Map<Object?, Object?>>[]).add(child);
    }
    final tree = <ContentCategory>[];
    for (final parent in parents.whereType<Map<Object?, Object?>>()) {
      final parentId = '${parent['cate1Id'] ?? ''}';
      if (parentId.isEmpty) {
        continue;
      }
      tree.add(ContentCategory(id: parentId, name: '${parent['cate1Name'] ?? ''}'));
      for (final child in byParent[parentId] ?? const <Map<Object?, Object?>>[]) {
        tree.add(
          ContentCategory(
            id: '${child['cate2Id'] ?? ''}',
            name: '${child['cate2Name'] ?? ''}',
            parentId: parentId,
            icon: _firstUrl(child, const <String>['icon', 'smallIcon', 'pic']),
          ),
        );
      }
    }
    // The source's own order, which the contract asks for: a category browser that reshuffles itself between
    // refreshes cannot be compared against what the user picked.
    _categoryTree = tree;
    return tree;
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) {
    final category = query.category?.trim();
    if (category == null || category.isEmpty) {
      return feed(query.page);
    }
    // `2_<cid>` is the directory's own prefix for a second-level category; the id comes from categories().
    return _roomList('$_directoryPath/2_$category/${query.page.page}', query.page);
  }

  /// One `data.rl` page: the recommend list and a category directory share this shape.
  Future<PageResult<ContentSummary>> _roomList(String url, PageRequest page) async {
    final json = await _client.getJson(url, headers: _device.headers());
    if (douyuInt(json['error']) != 0) {
      throw DouyuApiException('room list returned an error', errorCode: douyuInt(json['error']));
    }
    final data = douyuObject(json['data']);
    final rows = data?['rl'];
    if (rows is! List) {
      throw DouyuApiException('room list answered without data.rl');
    }
    final items = <ContentSummary>[
      for (final row in douyuRows(rows))
        if (douyuListRowIsLive(row)) douyuRoomFromListRow(row),
    ];
    final pageSize = page.pageSize > 0 ? page.pageSize : kDouyuListPageSize;
    final statedPages = data != null && data.containsKey('page') && data.containsKey('totalpage')
        ? (page: douyuInt(data['page']), total: douyuInt(data['totalpage']))
        : null;
    // The directory states its own page count; the recommend endpoint does not, where "this page came back
    // full" is the only continuation signal it gives. Saying false when nothing supports the claim is the
    // paging rule: a guessed true keeps a list spinning forever.
    final hasMore = statedPages == null ? rows.length >= pageSize : statedPages.page < statedPages.total;
    return PageResult<ContentSummary>(
      items: items,
      page: page.page,
      pageSize: pageSize,
      hasMore: hasMore,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final json = await _client.getJson(
      '$_profilePath/${ref.contentId}',
      headers: _device.headers(roomId: ref.contentId),
    );
    final room = json['room'];
    if (room is! Map) {
      throw DouyuApiException('room ${ref.contentId} profile answered without a room object');
    }
    final summary = douyuRoomFromProfile(room, roomId: ref.contentId);
    // The profile is the one answer that states live status outright, and a room page needs it: the list rows
    // it came from said only that the room was on air when the page was built.
    return ContentDetail(
      summary: ContentSummary(
        ref: summary.ref,
        title: summary.title,
        subtitle: summary.subtitle,
        cover: summary.cover,
        description: summary.description,
        metadata: ContentMetadata(
          popularity: summary.metadata.popularity,
          extra: <String, Object?>{...summary.metadata.extra, 'isLive': douyuRoomPayloadIsLive(room)},
        ),
      ),
      description: summary.description,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final pageSize = query.page.pageSize.clamp(1, 50);
    final json = await _client.getJson(
      _searchPath,
      headers: <String, String>{..._device.headers(), 'referer': 'https://www.douyu.com/search/'},
      queryParameters: <String, dynamic>{'kw': query.keyword, 'page': query.page.page, 'pageSize': pageSize},
    );
    if (douyuInt(json['error']) != 0) {
      throw DouyuApiException('search returned an error: ${json['msg'] ?? ''}', errorCode: douyuInt(json['error']));
    }
    final data = douyuObject(json['data']);
    final rows = data?['relateShow'];
    if (rows is! List) {
      throw DouyuApiException('search answered without data.relateShow');
    }
    final items = <ContentSummary>[for (final row in douyuRows(rows)) douyuRoomFromSearchRow(row)];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: pageSize,
      // Search states no total here; a full page is the signal, and anything else would be a guess.
      hasMore: rows.length >= pageSize,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final roomId = ref.contentId.trim();
    if (roomId.isEmpty) {
      throw DouyuApiException('room id is empty');
    }
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        // The first attempt is also the cheapest way to learn the cached descriptor went stale; only then is
        // a second fetch worth the round trip.
        return await _resolveOnce(roomId, forceRefresh: attempt > 0);
      } on DouyuApiException catch (error) {
        lastError = error;
      }
    }
    throw lastError!;
  }

  Future<MediaTicket> _resolveOnce(String roomId, {required bool forceRefresh}) async {
    final form = await _signer.sign(roomId, forceRefresh: forceRefresh);
    final response = await _client.post(
      '$_playPath/$roomId',
      body: form,
      headers: <String, String>{
        ..._device.headers(roomId: roomId),
        'content-type': 'application/x-www-form-urlencoded',
      },
    );
    Object? decoded;
    try {
      decoded = jsonDecode(response.data ?? '');
    } on FormatException catch (error) {
      // An edge that answers with an HTML block page instead of json is a failure to name, not a crash in the
      // room page that asked for the stream.
      throw DouyuApiException('H5 play answer was not json', cause: error);
    }
    if (decoded is! Map) {
      throw DouyuApiException('H5 play response is not an object');
    }
    final data = decoded['data'];
    final errorCode = decoded.containsKey('error') ? douyuInt(decoded['error']) : douyuInt(decoded['code']);
    if (errorCode != 0) {
      throw DouyuApiException('H5 play API error: ${decoded['msg'] ?? ''}', errorCode: errorCode);
    }
    if (data is! Map) {
      throw DouyuApiException('H5 play response is missing data');
    }
    final typed = Map<String, Object?>.from(data);
    return _ticketFor(roomId, typed);
  }

  MediaTicket _ticketFor(String roomId, Map<String, Object?> data) {
    final url = douyuPlayUrl(data);
    final uri = Uri.parse(url);
    final issuedAt = _clock().toUtc();
    // Anonymous urls carry `expire=<seconds since issue>`, not an absolute time, and the CDN closes the stream
    // at the end of that window. Without a ticket deadline the host has no signal to prefetch a replacement.
    final lease = douyuLeaseSeconds(uri);
    final expiresAt = lease == null ? null : issuedAt.add(Duration(seconds: lease));
    final lead = lease == null
        ? kDouyuPlayLeaseLead
        : (Duration(seconds: lease ~/ 4) < kDouyuPlayLeaseLead ? Duration(seconds: lease ~/ 4) : kDouyuPlayLeaseLead);
    final cdn = '${data['rtmp_cdn'] ?? ''}'.trim();

    return MediaTicket(
      id: '$douyuSourceId/$roomId',
      uri: uri,
      kind: MediaKind.live,
      protocol: douyuProtocolOf(uri),
      createdAt: issuedAt,
      expiresAt: expiresAt,
      headers: <String, String>{'user-agent': douyuUserAgent, 'referer': 'https://www.douyu.com/$roomId'},
      refresh: MediaTicketRefreshInfo(
        supported: true,
        expiresAt: expiresAt,
        // A lease that is quarters of its life away from ending is refreshed at its own lead, never at a flat
        // 45s a 60s url would spend most of its life inside.
        refreshBefore: expiresAt == null ? null : lead,
      ),
      source: ContentRef(sourceId: douyuSourceId, contentId: roomId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        isLive: true,
        extra: <String, Object?>{'container': douyuContainerOf(uri), if (cdn.isNotEmpty) 'cdn': cdn},
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // The ticket id names the room, so a refresh is a fresh lease on the same content and no state in this
    // source has to be preserved to get it.
    final prefix = '$douyuSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed contract method that throws synchronously escapes the caller's
      // `await` and the recovery ladder sitting behind it.
      throw DouyuApiException('ticket ${expired.id} does not name a douyu room');
    }
    return resolve(
      ContentRef(sourceId: douyuSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
    );
  }

  /// The first non-empty url among [keys], which is how the category icon has shipped in three shapes.
  static String? _firstUrl(Map<Object?, Object?> row, List<String> keys) {
    for (final key in keys) {
      final url = douyuAbsoluteUrl('${row[key] ?? ''}');
      if (url != null) {
        return url;
      }
    }
    return null;
  }
}

/// The playable url of one H5 play answer.
///
/// `rtmp_live` has shipped two ways: the signed media path (which must be joined to `rtmp_url`/`flv_url`) and,
/// in current responses, a complete url. A complete one has to win, because prefixing a second absolute url
/// yields a syntactically valid input like `https://cdn/live/https://other/live.flv` that nothing can open;
/// handing back a bare CDN directory is what produced the "input stream address format" failures.
String douyuPlayUrl(Map<String, Object?> data) {
  final live = douyuUnescape('${data['rtmp_live'] ?? ''}'.trim());
  if (douyuIsPlayableUrl(live)) {
    return live;
  }
  for (final baseKey in const <String>['rtmp_url', 'flv_url']) {
    final base = douyuUnescape('${data[baseKey] ?? ''}'.trim());
    if (base.isEmpty || live.isEmpty) {
      continue;
    }
    final joined = '${base.replaceFirst(RegExp(r'/+$'), '')}/${live.replaceFirst(RegExp(r'^/+'), '')}';
    if (douyuIsPlayableUrl(joined)) {
      return joined;
    }
  }
  for (final key in const <String>['player_1', 'stream_url', 'url']) {
    final value = douyuUnescape('${data[key] ?? ''}'.trim());
    if (douyuIsPlayableUrl(value)) {
      return value;
    }
  }
  // A complete FLV url can arrive without `rtmp_live` at all; the media-looking-path test is what keeps a
  // directory out of the recorder again.
  final flv = douyuUnescape('${data['flv_url'] ?? ''}'.trim());
  if (douyuIsDirectMediaUrl(flv)) {
    return flv;
  }
  throw DouyuApiException('H5 play response has no playable URL');
}

/// The `&amp;` a signed query is HTML-escaped into. Douyu's answers carry it, and a doubled-escaped `&` is a
/// parameter the CDN will not accept. Entities beyond this have not been seen in a response.
String douyuUnescape(String value) => value.replaceAll('&amp;', '&');

bool douyuIsPlayableUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.host.isNotEmpty && const <String>{'http', 'https', 'rtmp'}.contains(uri.scheme);
}

bool douyuIsDirectMediaUrl(String value) {
  if (!douyuIsPlayableUrl(value)) {
    return false;
  }
  final path = Uri.parse(value).path.toLowerCase();
  return path.endsWith('.flv') || path.endsWith('.m3u8') || path.endsWith('.mp4');
}

/// Seconds a signed url stays open, read from its own `expire` field. Null when the answer states none.
int? douyuLeaseSeconds(Uri uri) {
  final value = int.tryParse(uri.queryParameters['expire'] ?? '');
  return value != null && value > 0 ? value : null;
}

/// Transport, which is what [MediaProtocol] records. FLV is a container, so it goes to the metadata instead:
/// the enum has no member for it and merging the two is what platform-models.md section 11 forbids.
MediaProtocol douyuProtocolOf(Uri uri) {
  if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
    return uri.scheme == 'rtmp' ? MediaProtocol.rtmp : MediaProtocol.rtsp;
  }
  if (uri.path.toLowerCase().endsWith('.m3u8')) {
    return MediaProtocol.hls;
  }
  return uri.scheme == 'http' ? MediaProtocol.http : MediaProtocol.https;
}

String douyuContainerOf(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8')) {
    return 'm3u8';
  }
  if (path.endsWith('.flv')) {
    return 'flv';
  }
  return 'unknown';
}
