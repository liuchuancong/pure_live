// Module: lib/src/kugou/kugou_api.dart
// Purpose: 酷狗直播(繁星)的请求面:分类抓 HTML、目录 json、jsonp 搜索、房间信息与多线路拉流地址。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the shared query block, the `liveType`/`liveSessionId` state rule, the jsonp envelope
// and the pull-host/`txSecret` url checks follow the v1-maintained Kugou line
// (origin/master lib/shared/platforms/kugoulive/kugou_live_api.dart). Fresh implementation against the v2
// capability contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// Three things here are load-bearing and cannot be rediscovered from the responses:
//   * **on air is `liveType != -1` plus a non-empty `liveSessionId`** - `liveType == -1` is offline, and a room
//     with neither is *unknown*, not offline;
//   * **the pull url is validated against this room and this protocol** (`/live/` path, the site's own
//     `liveplay.live.kugou.com` host family, and a signed `txSecret`/`txTime` pair). A url that fails is dropped
//     rather than opened, because a borrowed or expired signature 403s with nothing naming the cause;
//   * **`rate`, `codec` and `layout` are one quality; the urls inside it are the lines.** Flattening the pair
//     into one list is how "1080p line 2" becomes unaddressable.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String kugouSourceId = 'kugou.live';
const String kugouWebOrigin = 'https://fanxing.kugou.com';
const String kugouApiOrigin = 'https://fx1.service.kugou.com';
const String kugouRoomInfoUrl = 'https://service2.fanxing.kugou.com/roomcen/room/web/cdn/getEnterRoomInfo';
const String kugouDirectoryPath = '/mfanxing-home/h5/cdn/room/index/list';
const String kugouCategoryDirectoryPath = '/mfanxing-home/h5/cdn/room/index/list_v4';
const String kugouSearchPath = '/pt_search/pcsearch/v1/type_all.jsonp';
const String kugouMediaPath = '/video/pc/live/pull/mutiline/streamaddr';

/// The category id the site uses for "recommend", which is answered by a different path than a real category.
const String kugouRecommendCategoryId = '8000';

const String kugouUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const Map<String, String> kugouHeaders = <String, String>{'user-agent': kugouUserAgent, 'referer': '$kugouWebOrigin/'};

/// The routes that are a viewer's own page rather than a category. Listing them as categories would put
/// "我的收藏" next to "音乐" in a browser that is supposed to be the site's taxonomy.
const Set<String> kugouPersonalRoutes = <String>{'3001', '3009', '3014', '3015'};

/// The pull host family. Any other host is not a kugou stream, however valid it looks.
const String kugouPullHost = 'liveplay.live.kugou.com';

final class KugouFailure implements Exception {
  const KugouFailure(this.message, {this.code, this.cause});

  final String message;
  final int? code;
  final Object? cause;

  @override
  String toString() => 'KugouFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

enum KugouBroadcast { live, offline, unknown }

/// One quality: the site's own rate/codec/layout triple, and the urls that carry it.
final class KugouVariant {
  const KugouVariant({
    required this.id,
    required this.container,
    required this.rate,
    required this.codec,
    required this.layout,
    required this.urls,
  });

  final String id;

  /// `flv` or `hls` - the container, which is part of the site's own identity for a profile.
  final String container;
  final int rate;
  final int codec;
  final int layout;
  final List<String> urls;
}

final class KugouCategory {
  const KugouCategory({required this.id, required this.name});

  final String id;
  final String name;
}

final class KugouRoomCard {
  const KugouRoomCard({
    required this.roomId,
    required this.nick,
    this.title,
    this.cover,
    this.avatar,
    this.viewers,
    this.categoryId,
  });

  final String roomId;
  final String nick;
  final String? title;
  final String? cover;
  final String? avatar;

  /// The number the list carried. Kugou labels it "人气" on some rows and "在线" on others and both arrive in this
  /// field, so it travels as stated rather than as our guess at which one it was.
  final int? viewers;
  final String? categoryId;

  ContentSummary toSummary() => ContentSummary(
    ref: ContentRef(sourceId: kugouSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: (title?.isNotEmpty ?? false) ? title! : nick,
    subtitle: nick,
    cover: cover,
    metadata: ContentMetadata(popularity: viewers),
  );
}

final class KugouRoom {
  const KugouRoom({
    required this.roomId,
    required this.state,
    required this.nick,
    this.kugouId,
    this.title,
    this.notice,
    this.avatar,
    this.cover,
    this.followers,
    this.variants = const <KugouVariant>[],
  });

  final String roomId;
  final KugouBroadcast state;
  final String nick;
  final String? kugouId;
  final String? title;
  final String? notice;
  final String? avatar;
  final String? cover;
  final int? followers;
  final List<KugouVariant> variants;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: kugouSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    // `unknown` is preserved rather than folded into ended: a room whose session field went missing is not a
    // room we know finished, and a follow list that reads it as finished stops watching.
    state: switch (state) {
      KugouBroadcast.live => LiveRoomState.live,
      KugouBroadcast.offline => LiveRoomState.ended,
      KugouBroadcast.unknown => LiveRoomState.unknown,
    },
    title: (title?.isNotEmpty ?? false) ? title! : nick,
    anchorName: nick,
    anchorId: kugouId,
    avatar: avatar,
    cover: cover,
    introduction: (notice?.isNotEmpty ?? false) ? notice : null,
    followers: followers,
    // No audience number on the entry-info endpoint; `null`, not 0.
    extra: <String, Object?>{if (kugouId != null) 'kugouId': kugouId},
  );
}

final class KugouDirectoryPage {
  const KugouDirectoryPage({required this.rooms, required this.hasMore});

  final List<KugouRoomCard> rooms;

  /// The endpoint's own `hasNextPage`. Absent reads as false, because a guessed true spins a list forever.
  final bool hasMore;
}

/// The kugou live client.
final class KugouApi {
  KugouApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The category table, scraped from the page the site itself renders.
  ///
  /// This is HTML, not a json api: kugou publishes no category list endpoint. Falling back to a static table
  /// when the scrape yields nothing is deliberate - an empty category browser looks like a site with no
  /// categories, and the static list is what the site had last time it was read.
  Future<List<KugouCategory>> categories() async {
    final body = await _get(kugouWebOrigin, null);
    final parsed = parseCategoriesHtml(body);
    return parsed.isEmpty ? kugouFallbackCategories : parsed;
  }

  /// One directory page. [categoryId] of [kugouRecommendCategoryId] is the recommend feed, which lives on a
  /// different path from a real category.
  Future<KugouDirectoryPage> directory({int page = 1, String categoryId = kugouRecommendCategoryId}) async {
    if (page < 1 || page > 10000) {
      throw const KugouFailure('directory pages are one-based and capped');
    }
    if (!RegExp(r'^\d{1,8}$').hasMatch(categoryId)) {
      throw KugouFailure('not a kugou category id: "$categoryId"');
    }
    final recommend = categoryId == kugouRecommendCategoryId;
    final query = <String, String>{
      'pid': '0',
      'kugouId': '0',
      'doubleLiveFirst': '1',
      'sysVersion': '0',
      'platform': '7',
      'device': 'PureLive-Web',
      'channel': '0',
      'version': '99999',
      'longitude': '0',
      'latitude': '0',
      'appid': '1010',
      'liveTypeFilter': '0',
      'isNew': '0',
      'entranceType': '0',
      'uiMode': '0',
      'page': '$page',
      // The recommend path ignores `cid`; a real category path requires it.
      if (!recommend) 'cid': categoryId,
    };
    final value = _decode(
      await _get('$kugouApiOrigin${recommend ? kugouDirectoryPath : kugouCategoryDirectoryPath}', query),
    );
    return parseDirectory(value);
  }

  /// Type-ahead search across anchors and rooms. jsonp, so the callback name is checked as well as the body.
  Future<List<KugouRoomCard>> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 100) {
      throw KugouFailure('a search keyword must be 1-100 characters, not "${query.length}"');
    }
    final callback = 'pureLive${DateTime.now().microsecondsSinceEpoch}';
    final body = await _get('$kugouApiOrigin$kugouSearchPath', <String, String>{
      'keywords': query,
      'nums': '200,0,0,0',
      'callback': callback,
    });
    return parseSearchJsonp(body, expectedCallback: callback);
  }

  /// The room, and its pull urls when [withStream] is set and it is on air.
  Future<KugouRoom> room(String rawRoomId, {bool withStream = false}) async {
    final roomId = validateRoomId(rawRoomId);
    final info = parseRoom(_decode(await _get(kugouRoomInfoUrl, <String, String>{'roomId': roomId})), roomId);
    if (!withStream || info.state != KugouBroadcast.live) {
      return info;
    }
    final mediaUri = Uri.parse('$kugouApiOrigin$kugouMediaPath').replace(
      queryParameters: <String, String>{
        'std_rid': roomId,
        'std_plat': '7',
        'std_kid': '0',
        'streamType': '1-2-4-5-8',
        'ua': 'fx-flash',
        'targetLiveTypes': '1-5-6',
        'version': '1000',
        'supportEncryptMode': '1',
        'appid': '1010',
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    final variants = parseMedia(_decode(await _get(mediaUri.toString(), null)), roomId);
    return KugouRoom(
      roomId: info.roomId,
      state: info.state,
      nick: info.nick,
      kugouId: info.kugouId,
      title: info.title,
      notice: info.notice,
      avatar: info.avatar,
      cover: info.cover,
      followers: info.followers,
      variants: variants,
    );
  }

  Future<String> _get(String url, Map<String, String>? query) async {
    // https only, and the response is decoded by us: the site's jsonp and its json answers arrive with
    // different framing, and letting the transport guess which one it got is where a parse starts lying.
    final uri = Uri.parse(url).replace(queryParameters: query);
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw KugouFailure('refusing to request a url that is not a clean https address: "$url"');
    }
    final response = await _client.getText(uri.toString(), headers: kugouHeaders);
    if (response.statusCode != 200) {
      throw KugouFailure('${uri.path} answered ${response.statusCode}', code: response.statusCode);
    }
    return response.body;
  }

  static String? decodeBody(String body) => body;

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw KugouFailure('the answer was not json', cause: error);
    }
  }

  /// `status`/`error_code` framing, then the `data` object.
  static Map<String, Object?> _data(Object? value) {
    final root = jsonMap(value);
    if (root == null) {
      throw const KugouFailure('answer is not a json object');
    }
    final status = jsonInt(root['status'] ?? root['error_code'] ?? root['code']);
    if (status != null && status != 0 && status != 1 && status != 200) {
      throw KugouFailure('kugou refused the request', code: status);
    }
    return jsonMap(root['data']) ?? root;
  }

  /// A kugou room id is a positive integer, and the web player also accepts a full `…/ roomId` link.
  static String validateRoomId(String value) {
    final text = value.trim();
    final digits = RegExp(r'(\d{1,12})$').firstMatch(text)?.group(1);
    if (digits == null || digits == '0') {
      throw KugouFailure('not a kugou room id: "$value"');
    }
    return digits;
  }

  static List<KugouCategory> parseCategoriesHtml(String body) {
    final pattern = RegExp(
      r'''href=["'](?:https://fanxing\.kugou\.com)?/pcindex/category/(\d{1,8})[^"']*["'][^>]*title=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final seen = <String>{};
    final categories = <KugouCategory>[];
    for (final match in pattern.allMatches(body)) {
      final id = match.group(1)!;
      final name = _htmlText(match.group(2)!);
      if (!kugouPersonalRoutes.contains(id) && name.isNotEmpty && seen.add(id)) {
        categories.add(KugouCategory(id: id, name: name));
      }
    }
    return categories;
  }

  /// The categories last read from the site, used only when the scrape yields nothing at all.
  static const List<KugouCategory> kugouFallbackCategories = <KugouCategory>[
    KugouCategory(id: '8000', name: '推荐'),
    KugouCategory(id: '2517', name: '音乐'),
    KugouCategory(id: '2522', name: '电台'),
  ];

  static KugouDirectoryPage parseDirectory(Object? value) {
    final data = _data(value);
    final rooms = <KugouRoomCard>[];
    final seen = <String>{};
    for (final entry in jsonList(data['list'])) {
      final wrapper = jsonMap(entry) ?? const <String, Object?>{};
      // Rows arrive wrapped two ways: flat, or as a `star` slot with the room one level down.
      final raw = wrapper['uiType'] == 'star' ? (jsonMap(wrapper['data']) ?? const <String, Object?>{}) : wrapper;
      final card = _card(raw);
      if (card != null && seen.add(card.roomId)) {
        rooms.add(card);
      }
    }
    return KugouDirectoryPage(rooms: rooms, hasMore: _truthy(data['hasNextPage']));
  }

  static List<KugouRoomCard> parseSearchJsonp(String body, {required String expectedCallback}) {
    final text = body.trim();
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    if (open <= 0 || close <= open) {
      throw const KugouFailure('the search answer is not a jsonp call');
    }
    final actual = text.substring(0, open).trim();
    // The callback we asked for must come back, and must be an identifier: a jsonp answer that ignores the
    // callback name is an html error page wearing a jsonp costume.
    if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$.]*$').hasMatch(actual) || actual != expectedCallback) {
      throw KugouFailure('the search answer named a different callback: "$actual"');
    }
    if (text.substring(close + 1).trim().replaceAll(';', '').isNotEmpty) {
      throw const KugouFailure('the search answer carries trailing content after the call');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text.substring(open + 1, close));
    } on FormatException catch (error) {
      throw KugouFailure('the jsonp payload was not json', cause: error);
    }
    final root = jsonMap(jsonMap(jsonMap(decoded)?['data'])?['anchor']) ?? const <String, Object?>{};
    final rooms = <KugouRoomCard>[];
    final seen = <String>{};
    for (final value in jsonList(root['list'])) {
      final card = _card(jsonMap(value) ?? const <String, Object?>{});
      if (card != null && seen.add(card.roomId)) {
        rooms.add(card);
      }
    }
    return rooms;
  }

  static KugouRoom parseRoom(Object? value, String expectedRoomId) {
    final roomId = validateRoomId(expectedRoomId);
    final data = _data(value);
    final normal = jsonMap(data['normalRoomInfo']) ?? const <String, Object?>{};
    final nick = '${normal['nickName'] ?? ''}'.trim();
    final kugouId = '${normal['kugouId'] ?? ''}'.trim();
    if (normal.isEmpty || (nick.isEmpty && kugouId.isEmpty)) {
      throw const KugouFailure('the room answer carries no anchor');
    }
    final liveType = jsonInt(data['liveType']) ?? 0;
    final session = '${data['liveSessionId'] ?? ''}'.trim();
    return KugouRoom(
      roomId: roomId,
      // The two-field rule: -1 is offline, a session means on air, anything else is unknown.
      state: liveType == -1
          ? KugouBroadcast.offline
          : session.isNotEmpty
          ? KugouBroadcast.live
          : KugouBroadcast.unknown,
      nick: nick.isEmpty ? '酷狗直播' : nick,
      kugouId: kugouId.isEmpty ? null : kugouId,
      title: '${data['liveName'] ?? ''}'.trim().isEmpty ? null : '${data['liveName']}'.trim(),
      notice: _firstText(<Object?>[normal['publicMesg'], normal['privateMesg']]),
      avatar: _image(normal['userLogo']),
      cover: _image(normal['imgPath']),
      followers: jsonInt(normal['fansCount']),
    );
  }

  static List<KugouVariant> parseMedia(Object? value, String expectedRoomId) {
    final roomId = validateRoomId(expectedRoomId);
    final data = _data(value);
    if ('${data['roomId'] ?? ''}'.trim() != roomId || jsonInt(data['status']) != 1) {
      throw const KugouFailure('the media answer is not about this room, or is not switched on');
    }
    final grouped = <String, _KugouBucket>{};
    for (final lineValue in jsonList(data['lines'])) {
      final line = jsonMap(lineValue) ?? const <String, Object?>{};
      for (final profileValue in jsonList(line['streamProfiles'])) {
        final profile = jsonMap(profileValue) ?? const <String, Object?>{};
        final rate = jsonInt(profile['rate']) ?? 0;
        final codec = jsonInt(profile['codec']) ?? 0;
        final layout = jsonInt(profile['layout']) ?? 0;
        for (final (key, container) in const <(String, String)>[('httpsFlv', 'flv'), ('httpsHls', 'hls')]) {
          final id = '$container:$rate:$codec:$layout';
          final bucket = grouped.putIfAbsent(id, () => _KugouBucket(container, rate, codec, layout));
          for (final raw in jsonList(profile[key])) {
            final url = _pullUrl('$raw', container: container);
            if (url != null && !bucket.urls.contains(url)) {
              bucket.urls.add(url);
            }
          }
        }
      }
    }
    final variants = <KugouVariant>[
      for (final entry in grouped.entries)
        if (entry.value.urls.isNotEmpty)
          KugouVariant(
            id: entry.key,
            container: entry.value.container,
            rate: entry.value.rate,
            codec: entry.value.codec,
            layout: entry.value.layout,
            urls: List<String>.unmodifiable(entry.value.urls),
          ),
    ]..sort((KugouVariant a, KugouVariant b) => b.rate.compareTo(a.rate));
    if (variants.isEmpty) {
      throw const KugouFailure('the media answer carried no address we are allowed to open');
    }
    return variants;
  }

  /// A pull url for this room and this container, or null.
  ///
  /// https only, the site's own pull host family, `/live/` in the path, the extension matching the container,
  /// and a signed `txSecret` plus a `txTime` that still looks like a hex expiry. A url that fails any of these
  /// is dropped: opening a borrowed or unsigned address produces a 403 that names nothing.
  static String? _pullUrl(String raw, {required String container}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        (uri.host != kugouPullHost && !uri.host.endsWith('.$kugouPullHost')) ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(container == 'hls' ? '.m3u8' : '.flv') ||
        uri.queryParameters['txSecret'] == null ||
        uri.queryParameters['txSecret']!.isEmpty ||
        !RegExp(r'^[0-9A-Fa-f]{8,16}$').hasMatch(uri.queryParameters['txTime'] ?? '')) {
      return null;
    }
    return raw.trim();
  }

  static KugouRoomCard? _card(Map<String, Object?> row) {
    final rawId = row['roomId'] ?? row['room_id'] ?? row['sid'];
    String roomId;
    try {
      roomId = validateRoomId('$rawId');
    } on KugouFailure {
      return null;
    }
    final nick = '${row['nickName'] ?? row['nick'] ?? ''}'.trim();
    if (nick.isEmpty) {
      return null;
    }
    final title = '${row['liveName'] ?? row['intro'] ?? ''}'.trim();
    return KugouRoomCard(
      roomId: roomId,
      nick: nick,
      title: title.isEmpty ? null : title,
      cover: _image(row['imgPath'] ?? row['cover']),
      avatar: _image(row['userLogo'] ?? row['avatar']),
      viewers: jsonInt(row['currentCount'] ?? row['online'] ?? row['hot']),
      categoryId: '${row['cid'] ?? row['categoryId'] ?? ''}'.trim().isEmpty
          ? null
          : '${row['cid'] ?? row['categoryId']}'.trim(),
    );
  }

  static bool _truthy(Object? value) => value == true || value == 1 || value == '1';

  static String? _image(Object? value) {
    var text = '${value ?? ''}'.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith('//')) {
      text = 'https:$text';
    }
    if (text.startsWith('/')) {
      text = 'https://p3.fx.kgimg.com$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return null;
    }
    // An http image url is upgraded rather than dropped: the web page serves it over https on the same host,
    // and a surface that refuses to load mixed content would show a blank tile for a room that has a cover.
    final upgraded = uri.scheme == 'http' ? uri.replace(scheme: 'https').toString() : text;
    return Uri.tryParse(upgraded)?.scheme == 'https' ? upgraded : null;
  }

  static String? _firstText(List<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static String _htmlText(String value) {
    const entities = <String, String>{'&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'"};
    var text = value.trim();
    entities.forEach((String key, String replacement) => text = text.replaceAll(key, replacement));
    return text;
  }
}

final class _KugouBucket {
  _KugouBucket(this.container, this.rate, this.codec, this.layout);

  final String container;
  final int rate;
  final int codec;
  final int layout;
  final List<String> urls = <String>[];
}
