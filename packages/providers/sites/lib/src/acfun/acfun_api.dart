// Module: lib/src/acfun/acfun_api.dart
// Purpose: AcFun 直播的请求面:目录游标、房间信息、访客会话、startPlay 换流与主播搜索的 HTML 读法。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: the endpoints, the visitor-login body, the startPlay parameter set and the two envelope codes
// (`result: 0` for live.acfun.cn, `result: 1` for api.kuaishouzt.com) follow the v1-maintained AcFun line
// (origin/master lib/shared/platforms/acfun/). Fresh implementation against the v2 capability contracts, not a
// file merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, acfun_site.dart owns the capability answers. No model file - what a caller receives is the
// shared platform models.
//
// The envelope codes are not decoration: a room that is closed and a room that does not exist both answer
// `result: 0`, and the only thing that tells either apart from a schema change is that the identity fields still
// line up. So every read here ends by checking `authorId` against `user.id` - an answer whose identity does not
// complete is an answer about nobody, and guessing "offline" from it stops a follow list watching a live room.

import 'dart:convert';
import 'dart:math';

import 'package:html/dom.dart' show DocumentFragment, Element;
import 'package:html/parser.dart' show parseFragment;
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

/// The source id every acfun row carries. Stored inside favourite and history rows; renaming orphans them.
const String acfunSourceId = 'acfun.live';

/// `live.acfun.cn` - the directory, the room envelope and the web room page.
const String acfunLiveOrigin = 'https://live.acfun.cn';

const String acfunDirectoryPath = '/api/channel/list';
const String acfunRoomInfoPath = '/api/live/info';

/// `id.app.acfun.cn` - the anonymous visitor the play endpoint insists on.
const String acfunVisitorUrl = 'https://id.app.acfun.cn/rest/app/visitor/login';

/// `api.kuaishouzt.com` - the play endpoint. AcFun's live delivery sits on Kuaishou's stack; the host is the
/// site's own, not a mistake to "fix" back to live.acfun.cn.
const String acfunStartPlayUrl = 'https://api.kuaishouzt.com/rest/zt/live/web/startPlay';

/// `www.acfun.cn/search?...&type=user` - the anchor search page. It answers HTML, not json.
const String acfunSearchUrl = 'https://www.acfun.cn/search';

/// The page size the search endpoint uses. It is the server's, so a requested size becomes how many of *those*
/// pages we consume, not a `count` parameter the endpoint would ignore.
const int acfunSearchServerPageSize = 30;

const String acfunUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// The headers the live endpoints answer to. `referer` is what the play host checks; the visitor cookie is
/// per-request and deliberately not baked in here.
const Map<String, String> acfunWebHeaders = <String, String>{
  'user-agent': acfunUserAgent,
  'referer': '$acfunLiveOrigin/',
};

/// How long one visitor session is reused. The web client re-logs in every five minutes; a session that outlives
/// the server's own idea of one makes startPlay answer `result != 1` with no way to tell why.
const Duration acfunVisitorLifetime = Duration(minutes: 5);

/// How long to sit out after a failed visitor login. Without it, every room opened during an outage costs a login
/// request plus its own timeout - a retry storm against the endpoint that is already down.
const Duration acfunVisitorBackoff = Duration(minutes: 1);

/// An AcFun answer that is not the answer we asked for.
///
/// Named rather than a bare StateError because "the room is closed", "the shape changed" and "the edge refused
/// us" need different handling upstream: the first is a fact to show, the second is a bug to chase, the third is
/// a retry.
final class AcfunApiFailure implements Exception {
  const AcfunApiFailure(this.message, {this.result, this.cause});

  final String message;

  /// The endpoint's own `result` code, when it answered with one.
  final int? result;
  final Object? cause;

  @override
  String toString() =>
      'AcfunApiFailure($message'
      '${result == null ? '' : ', result $result'}'
      '${cause == null ? '' : ': $cause'})';
}

/// One quality as `startPlay` described it: a label, the source's own rank, and the urls that carry it.
final class AcfunQuality {
  const AcfunQuality({required this.id, required this.label, required this.rank, required this.urls});

  final String id;
  final String label;

  /// The source's ordering weight, higher first. See [AcfunApi._qualities] for why it is not just a bitrate.
  final int rank;
  final List<String> urls;
}

/// What `startPlay` handed back for one room.
final class AcfunPlayback {
  const AcfunPlayback({
    required this.liveId,
    required this.qualities,
    required this.tickets,
    required this.enterRoomAttach,
  });

  final String liveId;
  final List<AcfunQuality> qualities;

  /// The danmaku handshake material. The socket is a later slice; carrying them here is what keeps the play
  /// request from having to be made twice when it lands.
  final List<String> tickets;
  final String enterRoomAttach;

  AcfunQuality? qualityById(String id) {
    for (final quality in qualities) {
      if (quality.id == id) {
        return quality;
      }
    }
    return null;
  }

  /// The best-ranked entry; the manifest list arrives unsorted and the web client picks the top.
  AcfunQuality? get preferred => qualities.isEmpty ? null : qualities.first;
}

/// One directory page: the room rows, the continuation cursor, and the filter table when the answer carried one.
final class AcfunDirectoryPage {
  const AcfunDirectoryPage({required this.rooms, this.cursor, this.categories = const <AcfunCategory>[]});

  final List<Map<String, Object?>> rooms;

  /// Null means the endpoint said `no_more` - the end of the list, not a page we failed to read.
  final String? cursor;
  final List<AcfunCategory> categories;
}

/// One category filter. AcFun names categories by a *(type, id) pair and `type` is part of the wire query -
/// dropping it is how a category browse quietly returns the whole directory.
final class AcfunCategory {
  const AcfunCategory({required this.type, required this.id, required this.name, this.cover});

  final int type;
  final int id;
  final String name;
  final String? cover;

  static String encode(int type, int id) => 'liveChannelFilter/$type/$id';
}

/// One anchor card read out of the search page.
final class AcfunSearchCard {
  const AcfunSearchCard({
    required this.authorId,
    required this.name,
    this.avatar,
    this.introduction,
    this.followerLabel,
    this.isLive,
  });

  final String authorId;
  final String name;
  final String? avatar;
  final String? introduction;

  /// The follower count exactly as the page worded it ("1.2万"). AcFun gives no number here, and turning the label
  /// into a guessed integer would put our arithmetic on the platform's figure.
  final String? followerLabel;

  /// Null when the card does not say - which is not "offline".
  final bool? isLive;
}

/// One search page: the cards plus the total the page states, when it states one.
final class AcfunSearchPage {
  const AcfunSearchPage({required this.cards, required this.total, required this.page});

  final List<AcfunSearchCard> cards;

  /// `data-total` from the result header. Null means the page carried no total at all.
  final int? total;
  final int page;
}

final class _AcfunVisitorSession {
  const _AcfunVisitorSession({required this.did, required this.userId, required this.token, required this.usableUntil});

  final String did;
  final String userId;
  final String token;
  final DateTime usableUntil;
}

/// The AcFun client. One [NetworkClient] per instance, closed only when this client built it.
final class AcfunApi {
  AcfunApi({NetworkClient? client, Clock? clock, Random? random})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock,
      _random = random ?? Random.secure();

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;
  final Random _random;

  _AcfunVisitorSession? _visitor;
  Future<_AcfunVisitorSession>? _visitorInFlight;
  DateTime? _visitorRefusedUntil;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// One directory page. [cursor] is the endpoint's own `pcursor`; [filters] is an [AcfunCategory.encode] pair.
  Future<AcfunDirectoryPage> directory({String cursor = '', int count = 30, String? filters}) async {
    final data = await _client.getJson(
      '$acfunLiveOrigin$acfunDirectoryPath',
      headers: acfunWebHeaders,
      queryParameters: <String, Object?>{
        'count': count.clamp(1, 60),
        'pcursor': cursor,
        if (filters != null) 'filters': filters,
      },
    );
    final envelope = jsonMap(data['channelListData']) ?? data;
    _expectResult(envelope, 0, 'directory');
    // A page without `pcursor` is not an empty last page: the endpoint always answers one, and its absence means
    // we are reading a response we do not have a shape for.
    if (!envelope.containsKey('pcursor')) {
      throw const AcfunApiFailure('directory answered without a pcursor field');
    }
    final next = '${envelope['pcursor'] ?? ''}'.trim();
    return AcfunDirectoryPage(
      rooms: <Map<String, Object?>>[
        for (final row in jsonList(envelope['liveList']))
          if (jsonMap(row) case final Map<String, Object?> item) item,
      ],
      cursor: next.isEmpty || next == 'no_more' ? null : next,
      categories: _categories(data['channelFilters']),
    );
  }

  /// The room envelope for one anchor. AcFun addresses a live room by the *author's* id, not by a room id.
  Future<Map<String, Object?>> roomInfo(String authorId) async {
    final id = normalizeAuthorId(authorId);
    final data = await _client.getJson(
      '$acfunLiveOrigin$acfunRoomInfoPath',
      headers: acfunWebHeaders,
      queryParameters: <String, Object?>{'authorId': id},
    );
    // The envelope names its author in `user.id` but not always at the top level; the id we asked with is the
    // one liveInRoomEnvelope compares against, so it is filled in rather than trusted to appear.
    return <String, Object?>{...data, if (data['authorId'] == null) 'authorId': id};
  }

  /// Whether the envelope describes a room that is on air, and why it says so.
  static bool liveInRoomEnvelope(Map<String, Object?> data, String authorId) {
    _expectResult(data, 0, 'room info');
    final user = jsonMap(data['user']) ?? const <String, Object?>{};
    final envelopeId = '${data['authorId'] ?? ''}'.trim();
    final userId = '${user['id'] ?? ''}'.trim();
    if (envelopeId.isNotEmpty && envelopeId != authorId) {
      throw AcfunApiFailure('room info answered for $envelopeId while asking about $authorId');
    }
    if (userId != authorId || '${user['name'] ?? ''}'.trim().isEmpty) {
      throw const AcfunApiFailure('room info envelope does not identify its author');
    }
    final liveId = '${data['liveId'] ?? ''}'.trim();
    final stream = '${data['streamName'] ?? ''}'.trim();
    if (liveId.isEmpty != stream.isEmpty) {
      throw const AcfunApiFailure('room info carries a liveId without a stream name, or the reverse');
    }
    return liveId.isNotEmpty;
  }

  /// The play material for one room: visitor session, then `startPlay`.
  Future<AcfunPlayback> playback(String authorId) async {
    final id = normalizeAuthorId(authorId);
    final session = await _session();
    final Map<String, Object?> data;
    try {
      data = await _postForm(
        acfunStartPlayUrl,
        <String, Object?>{'authorId': id, 'pullStreamType': 'FLV'},
        <String, Object?>{
          'subBiz': 'mainApp',
          'kpn': 'ACFUN_APP',
          'kpf': 'PC_WEB',
          'userId': session.userId,
          'did': session.did,
          'acfun.api.visitor_st': session.token,
        },
        <String, String>{...acfunWebHeaders, 'cookie': '_did=${session.did};'},
      );
      _expectResult(data, 1, 'startPlay');
    } on AcfunApiFailure {
      // The session is the only variable here: if it is what the endpoint rejected, drop it so the next attempt
      // logs in fresh rather than replaying the same rejected token forever.
      if (identical(_visitor, session)) {
        _visitor = null;
      }
      rethrow;
    }
    final payload = jsonMap(data['data']) ?? const <String, Object?>{};
    final liveId = '${payload['liveId'] ?? ''}'.trim();
    if (liveId.isEmpty) {
      throw const AcfunApiFailure('startPlay answered without a liveId');
    }
    return AcfunPlayback(
      liveId: liveId,
      qualities: _qualities(payload['videoPlayRes']),
      tickets: <String>[
        for (final ticket in jsonList(payload['availableTickets']))
          if ('${ticket ?? ''}'.trim().isNotEmpty) '${ticket}'.trim(),
      ],
      enterRoomAttach: '${payload['enterRoomAttach'] ?? ''}'.trim(),
    );
  }

  /// The anonymous visitor's material, as the danmaku handshake will want it when that slice lands.
  Future<({String userId, String did, String token})> visitorCredentials() async {
    final session = await _session();
    return (userId: session.userId, did: session.did, token: session.token);
  }

  /// One page of the anchor search. The endpoint answers a json envelope wrapping an HTML fragment, so the cards
  /// are read with the parser rather than a regex over markup.
  Future<AcfunSearchPage> search(String keyword, {int page = 1}) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return AcfunSearchPage(cards: const <AcfunSearchCard>[], total: 0, page: page);
    }
    if (page < 1) {
      throw const AcfunApiFailure('search pages are one-based');
    }
    final body = await _client.getText(
      acfunSearchUrl,
      headers: <String, String>{'user-agent': acfunUserAgent, 'referer': '$acfunSearchUrl'},
      queryParameters: <String, Object?>{
        'keyword': query,
        'type': 'user',
        'pCursor': '$page',
        'quickViewId': 'up-list',
        'reqID': '1',
        'ajaxpipe': '1',
      },
    );
    return _parseSearchPage(body.body, page);
  }

  AcfunSearchPage _parseSearchPage(String body, int page) {
    // The ajaxpipe answer is the json document followed by the rest of the page; only the first object matters.
    final separator = body.indexOf('ajaxpipe-branch-skeleton');
    final head = separator < 0 ? body : body.substring(0, separator);
    Object? decoded;
    try {
      decoded = jsonDecode(head.trim());
    } on FormatException catch (error) {
      throw AcfunApiFailure('search answer was not the json envelope', cause: error);
    }
    if (decoded is! Map) {
      throw const AcfunApiFailure('search answer envelope is not an object');
    }
    final fragment = parseFragment('${Map<String, Object?>.from(decoded)['html'] ?? ''}');
    final header = fragment.querySelector('.total-num[data-total]');
    if (header == null) {
      throw const AcfunApiFailure('search answer carries no result total');
    }
    final cards = fragment.querySelectorAll('.search-up');
    final total = jsonInt(header.attributes['data-total']) ?? _totalFromText(header.text);
    // "共0条结果" with an empty page is a real answer. Anything else that leaves the count unknowable is a shape
    // change, and reading *that* as "no results" would show an empty search for a site that has plenty.
    if (total == null && !(cards.isEmpty && _isZeroPage(fragment))) {
      throw const AcfunApiFailure('search result total is unreadable');
    }
    if (cards.length > acfunSearchServerPageSize) {
      throw const AcfunApiFailure('search page carries more cards than its own page size');
    }
    return AcfunSearchPage(
      cards: <AcfunSearchCard>[
        for (final card in cards)
          if (_searchCard(card) case final AcfunSearchCard row) row,
      ],
      total: total,
      page: page,
    );
  }

  static bool _isZeroPage(DocumentFragment fragment) =>
      fragment.querySelector('.empty-page') != null ||
      '${fragment.text}'.replaceAll(RegExp(r'\s'), '').contains('共0条结果');

  /// "共0条结果" - the only total the page ever words out instead of putting in the attribute.
  static int? _totalFromText(String text) => text.replaceAll(RegExp(r'\s'), '') == '共0条结果' ? 0 : null;

  AcfunSearchCard? _searchCard(Element card) {
    // The identity lives in the exposure log the page attaches to the card; the anchor link is what names it.
    final meta = _exposureMeta(card.attributes['data-up-exposure-log']);
    final id = '${meta['up_id'] ?? ''}'.trim();
    if (!_authorIdPattern.hasMatch(id)) {
      return null;
    }
    final link = card.querySelector('.up__main__name a');
    final name = link?.text.trim() ?? '';
    if (name.isEmpty || !_linkIsOwnProfile(link?.attributes['href'] ?? '', id)) {
      // A card whose link does not go to the author it names is a card we cannot open, so it is not a row.
      return null;
    }
    return AcfunSearchCard(
      authorId: id,
      name: name,
      avatar: _absoluteImage(card.querySelector('img.up__avatar')?.attributes['src']),
      introduction: card.querySelector('.up__main__intro')?.text.trim(),
      followerLabel: _followerLabel(card.querySelector('.info__danmaku-count')?.text ?? ''),
      isLive: switch (meta['is_on_live']) {
        final bool value => value,
        final String text => text.trim().isEmpty ? null : true,
        _ => null,
      },
    );
  }

  /// The profile link must point at the same author the exposure log names: the page is somebody else's markup,
  /// and a card mixing two authors would put one person's room on another's row.
  static bool _linkIsOwnProfile(String href, String authorId) {
    final uri = Uri.tryParse(href);
    if (uri == null) {
      return false;
    }
    if (uri.hasAuthority && !const <String>{'www.acfun.cn', 'acfun.cn'}.contains(uri.host)) {
      return false;
    }
    if (uri.hasScheme && !const <String>{'http', 'https'}.contains(uri.scheme)) {
      return false;
    }
    return uri.userInfo.isEmpty && uri.path == '/u/$authorId';
  }

  static final RegExp _authorIdPattern = RegExp(r'^[1-9][0-9]{0,19}$');

  static final RegExp _followerPattern = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?[万亿]?)\s*粉丝\s*$');

  /// The card's identity payload. The page puts it in an HTML attribute, so what arrives is **json text** with
  /// the quotes already entity-decoded by the parser - treating the attribute as a Map would silently drop every
  /// card, which is the shape of "search returns nothing and nothing failed".
  static Map<String, Object?> _exposureMeta(Object? raw) {
    if (raw is Map) {
      return Map<String, Object?>.from(raw);
    }
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) {
      return const <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? Map<String, Object?>.from(decoded) : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  static String? _followerLabel(String text) => _followerPattern.firstMatch(text)?.group(1);

  static String? _absoluteImage(Object? raw) {
    var value = '${raw ?? ''}'.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('//')) {
      value = 'https:$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return null;
    }
    // An authority carrying userinfo is not a picture url; it is a url built to look like one.
    return uri.userInfo.isEmpty ? value : null;
  }

  List<AcfunCategory> _categories(Object? raw) {
    final groups = jsonList(jsonMap(raw)?['liveChannelDisplayFilters']);
    final byPair = <(int, int), AcfunCategory>{};
    for (final group in groups) {
      for (final filter in jsonList(jsonMap(group)?['displayFilters'])) {
        final item = jsonMap(filter);
        if (item == null) {
          continue;
        }
        final type = jsonInt(item['filterType']);
        final id = jsonInt(item['filterId']);
        final name = '${item['name'] ?? ''}'.trim();
        // `filterId 0` is the site's own "全部" row: listing it would put a category on the browser that returns
        // what browse-without-a-category already returns.
        if (type == null || type < 0 || id == null || id <= 0 || name.isEmpty) {
          continue;
        }
        byPair.putIfAbsent((
          type,
          id,
        ), () => AcfunCategory(type: type, id: id, name: name, cover: _absoluteImage(item['cover'])));
      }
    }
    return byPair.values.toList(growable: false);
  }

  /// The manifest list into qualities, ordered by the site's own level and only then by bitrate.
  ///
  /// `level` and `bitrate` are two different scales on the same row: sorting the mixed pair numerically puts a
  /// 2000-bitrate unknown level above a level-5 "蓝光", which is the wrong answer in both groups. Known levels get
  /// their own band so they always sort ahead, and the bitrate only orders the unknowns.
  List<AcfunQuality> _qualities(Object? raw) {
    final manifests = jsonList(jsonMap(raw)?['liveAdaptiveManifest']);
    if (manifests.isEmpty) {
      throw const AcfunApiFailure('startPlay answered with no adaptive manifest');
    }
    final byId = <String, AcfunQuality>{};
    for (final manifest in manifests) {
      final adaptation = jsonMap(jsonMap(manifest)?['adaptationSet']) ?? const <String, Object?>{};
      final representations = jsonList(adaptation['representation']);
      for (final rawRepresentation in representations) {
        final item = jsonMap(rawRepresentation);
        if (item == null || item['hidden'] == true) {
          continue;
        }
        final url = _absoluteMediaUrl(item['url']);
        if (url == null) {
          continue;
        }
        final type = '${item['qualityType'] ?? ''}'.trim();
        final id = type.isNotEmpty ? type : 'id:${jsonInt(item['id']) ?? ''}';
        if (id == 'id:') {
          throw const AcfunApiFailure('a quality row carries neither a qualityType nor an id');
        }
        final level = jsonInt(item['level']);
        final rank = level != null && level >= 0
            ? 1000000 + level.clamp(0, 999999)
            : (jsonInt(item['bitrate']) ?? 0).clamp(0, 999999);
        final name = '${item['name'] ?? ''}'.trim();
        final previous = byId[id];
        byId[id] = AcfunQuality(
          id: id,
          label: (previous?.label ?? '').isNotEmpty ? previous!.label : (name.isNotEmpty ? name : id),
          rank: rank > (previous?.rank ?? rank) ? rank : (previous?.rank ?? rank),
          urls: <String>{...?previous?.urls, url}.toList(growable: false),
        );
      }
    }
    if (byId.isEmpty) {
      throw const AcfunApiFailure('startPlay described no playable quality');
    }
    final ordered = byId.values.toList()
      ..sort((AcfunQuality a, AcfunQuality b) {
        final byRank = b.rank.compareTo(a.rank);
        return byRank != 0 ? byRank : a.id.compareTo(b.id);
      });
    return List<AcfunQuality>.unmodifiable(ordered);
  }

  static String? _absoluteMediaUrl(Object? value) {
    final url = '${value ?? ''}'.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme)) {
      return null;
    }
    return uri.host.isEmpty || uri.userInfo.isNotEmpty ? null : url;
  }

  /// The visitor session, logged in once and shared; a second room opening at the same time waits for the first
  /// login rather than asking twice for an identity the site hands out per device.
  Future<_AcfunVisitorSession> _session() async {
    final now = _clock();
    final cached = _visitor;
    if (cached != null && now.isBefore(cached.usableUntil)) {
      return cached;
    }
    final refusedUntil = _visitorRefusedUntil;
    if (refusedUntil != null && now.isBefore(refusedUntil)) {
      throw AcfunApiFailure(
        'the visitor session could not be obtained; retrying after ${refusedUntil.toIso8601String()}',
      );
    }
    final running = _visitorInFlight;
    if (running != null) {
      return running;
    }
    late final Future<_AcfunVisitorSession> operation;
    operation = _login()
        .catchError((Object error) {
          _visitorRefusedUntil = _clock().add(acfunVisitorBackoff);
          throw error;
        })
        .whenComplete(() {
          if (identical(_visitorInFlight, operation)) {
            _visitorInFlight = null;
          }
        });
    _visitorInFlight = operation;
    return operation;
  }

  Future<_AcfunVisitorSession> _login() async {
    final did = _newDeviceId();
    final data = await _postForm(
      acfunVisitorUrl,
      <String, Object?>{'sid': 'acfun.api.visitor'},
      null,
      <String, String>{...acfunWebHeaders, 'cookie': '_did=$did;'},
    );
    _expectResult(data, 0, 'visitor login');
    final userId = normalizeAuthorId('${data['userId'] ?? ''}');
    final token = '${data['acfun.api.visitor_st'] ?? ''}'.trim();
    if (token.isEmpty) {
      throw const AcfunApiFailure('visitor login answered without a session token');
    }
    final session = _AcfunVisitorSession(
      did: did,
      userId: userId,
      token: token,
      usableUntil: _clock().add(acfunVisitorLifetime),
    );
    _visitor = session;
    _visitorRefusedUntil = null;
    return session;
  }

  /// The device id the web client generates per session: `web_` plus 16 base-36 characters from a cryptographic
  /// source. Deriving it from the clock would make it guessable and one-per-microsecond, which is not an identity.
  String _newDeviceId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'web_${List<String>.generate(16, (_) => alphabet[_random.nextInt(alphabet.length)]).join()}';
  }

  Future<Map<String, Object?>> _postForm(
    String url,
    Map<String, Object?> fields,
    Map<String, Object?>? query,
    Map<String, String> headers,
  ) async {
    final response = await _client.postForm(url, fields, headers: headers, queryParameters: query);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw AcfunApiFailure('${Uri.parse(url).path} answered a non-object body');
      }
      return Map<String, Object?>.from(decoded);
    } on FormatException catch (error) {
      // An edge that answers an HTML block page instead of json is a failure to name, not a crash in the room
      // page that asked for the stream.
      throw AcfunApiFailure('${Uri.parse(url).path} answered something that is not json', cause: error);
    }
  }

  static void _expectResult(Map<String, Object?> data, int expected, String what) {
    final code = jsonInt(data['result']);
    if (code == null) {
      throw AcfunApiFailure('$what answered without a result code', result: null);
    }
    if (code != expected) {
      throw AcfunApiFailure('$what refused', result: code);
    }
  }

  /// An AcFun author id is a positive integer that fits 64 bits; anything else is not an id this site has.
  static String normalizeAuthorId(String value) {
    final result = value.trim();
    if (!_authorIdPattern.hasMatch(result)) {
      throw const AcfunApiFailure('not an AcFun author id');
    }
    return result;
  }
}
