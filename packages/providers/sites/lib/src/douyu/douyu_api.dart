// Module: lib/src/douyu/douyu_api.dart
// Purpose: Douyu's websec encryption descriptor, the signed play form built from it, and the urls both are sent to.
// Author: liuchuancong
// Created: 2026-10-10
//
// Provenance: the endpoint, the descriptor fields and the md5 chain follow the v1-maintained Douyu line
// (origin/master lib/core/network/douyu_utils.dart). This is a fresh implementation against the v2
// capability contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Deliberately smaller than the v1 line: no
// pasted login cookie, no passport/JWT renewal, no quality or line picking - an anonymous viewer only, which is
// what the feed-to-room chain needs to be real end to end.
//
// One file because this is one site's request side, and a site is two files (docs/architecture/package-architecture.md
// §2): the device id, the descriptor issued to it, the md5 chain that turns both into an `auth`, the urls both are
// sent to, and the readers for what those requests return - and douyu_site.dart, which only answers the platform's
// capability interfaces from them. No per-site model file: the shapes a caller receives are the shared ones in
// pure_live_platform, and 30+ 站点 each carrying their own model set would be 30+ copies of the same room and
// ticket.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../common/site_json.dart';

/// The desktop Chrome user agent the web endpoints answer to without a login.
const String douyuUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/128.0.0.0 Safari/537.36';

/// Where the signing material comes from.
const String kDouyuEncryptionEndpoint = 'https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption';

/// `japi/weblist/apinc/allpage/6` - the recommend feed, one page per path segment.
const String kDouyuFeedPath = 'https://www.douyu.com/japi/weblist/apinc/allpage/6';

/// `m.douyu.com/api/cate/list` - the flat cate1/cate2 tables the category tree is assembled from.
const String kDouyuCategoryTreePath = 'https://m.douyu.com/api/cate/list';

/// `gapi/rkc/directory/mixList` - a second-level category's room list, addressed as `2_<cid>`.
const String kDouyuDirectoryPath = 'https://www.douyu.com/gapi/rkc/directory/mixList';

/// `betard/<roomId>` - the room profile, the only answer that states live status outright.
const String kDouyuProfilePath = 'https://www.douyu.com/betard';

/// `japi/search/api/searchShow` - room search. States no total, so a full page is the only continuation signal.
const String kDouyuSearchPath = 'https://www.douyu.com/japi/search/api/searchShow';

/// `lapi/live/getH5PlayV1` - the signed play request the descriptor exists to authorise.
const String kDouyuPlayPath = 'https://www.douyu.com/lapi/live/getH5PlayV1';

/// How long a signed play url is worth prefetching for when the answer states no expiry of its own.
const Duration kDouyuPlayLeaseLead = Duration(seconds: 45);

/// A descriptor is refused this close to its own expiry: signing with one that dies mid-request hands the
/// player a url that stops before the stream is opened.
const int kDouyuDescriptorSafetySeconds = 30;

/// How long one descriptor may be reused regardless of what it claims about its own expiry.
const int kDouyuDescriptorMaxAgeSeconds = 5 * 60;

/// `enc_time` is a round count the server chooses; v1 refused anything outside 1..16 rather than loop an
/// unbounded number of times on a hostile answer.
const int kDouyuMaxEncryptionRounds = 16;

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

/// The device a descriptor is issued to.
///
/// Douyu validates the signed request against the same device the descriptor was handed to, and a mismatch is
/// answered with a plain 403 from its edge - no API error to name - so the id has to reach the descriptor
/// query, the form field and the cookie from one place.
final class DouyuDevice {
  DouyuDevice({String? deviceId, Random? random})
    : deviceId = (deviceId == null || deviceId.isEmpty) ? generateDouyuDeviceId(random ?? Random.secure()) : deviceId;

  final String deviceId;

  /// The two cookie fields Douyu reads the device from; an anonymous session has nothing else to send.
  String get cookieHeader => 'dy_did=$deviceId; acf_did=$deviceId';

  Map<String, String> headers({String roomId = ''}) => <String, String>{
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'origin': 'https://www.douyu.com',
    'referer': roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId',
    'user-agent': douyuUserAgent,
    'cookie': cookieHeader,
  };
}

/// A 32-character hex device id, the shape the web client generates per session.
String generateDouyuDeviceId(Random random) =>
    List<String>.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();

/// The server-side signing material for one device.
final class DouyuEncryptionDescriptor {
  const DouyuEncryptionDescriptor({
    required this.key,
    required this.randStr,
    required this.encData,
    required this.encTime,
    required this.expireAt,
    required this.isSpecial,
  });

  factory DouyuEncryptionDescriptor.fromJson(Map<String, Object?> json) {
    final missing = <String>[
      for (final field in const <String>['key', 'rand_str', 'enc_data'])
        if ('${json[field] ?? ''}'.trim().isEmpty) field,
    ];
    if (missing.isNotEmpty) {
      throw FormatException('Douyu encryption descriptor is missing ${missing.join(', ')}');
    }
    return DouyuEncryptionDescriptor(
      key: '${json['key']}',
      randStr: '${json['rand_str']}',
      encData: '${json['enc_data']}',
      encTime: jsonInt(json['enc_time']) ?? 0,
      expireAt: jsonInt(json['expire_at']) ?? 0,
      isSpecial: jsonInt(json['is_special']) == 1,
    );
  }

  final String key;
  final String randStr;
  final String encData;

  /// md5 rounds to run. Server-chosen, not a local constant.
  final int encTime;

  /// Absolute unix seconds, not a lifetime.
  final int expireAt;

  /// The descriptor family that omits the room+timestamp salt.
  final bool isSpecial;

  bool isUsable({required int nowSeconds, int safetySeconds = kDouyuDescriptorSafetySeconds}) =>
      expireAt > nowSeconds + safetySeconds &&
      encTime > 0 &&
      encTime <= kDouyuMaxEncryptionRounds &&
      key.isNotEmpty &&
      randStr.isNotEmpty &&
      encData.isNotEmpty;
}

/// The form body one play request is made of, in the order the web client sends it.
///
/// The chain is the server's, not a local convention: `enc_time` md5 rounds over `rand_str` and `key`, then a
/// final round with the salt, which is the room id plus the timestamp except for [isSpecial] descriptors.
/// Re-ordering the concatenation yields an `auth` the API answers `error != 0` for, with no reason given.
String douyuSignedForm({
  required DouyuEncryptionDescriptor descriptor,
  required String roomId,
  required int timestampSeconds,
  required String deviceId,
  int rate = -1,
  String cdn = '',
}) {
  if (!descriptor.isUsable(nowSeconds: timestampSeconds, safetySeconds: 0)) {
    throw StateError('Douyu encryption descriptor is expired or incomplete');
  }
  var secret = descriptor.randStr;
  for (var round = 0; round < descriptor.encTime; round++) {
    secret = md5.convert(utf8.encode('$secret${descriptor.key}')).toString();
  }
  final salt = descriptor.isSpecial ? '' : '$roomId$timestampSeconds';
  final auth = md5.convert(utf8.encode('$secret${descriptor.key}$salt')).toString();
  return Uri(
    queryParameters: <String, String>{
      'enc_data': descriptor.encData,
      'tt': '$timestampSeconds',
      'did': deviceId,
      'auth': auth,
      'cdn': cdn,
      'rate': '$rate',
      'hevc': '0',
      'fa': '0',
      'ive': '0',
      'ver': 'Douyu_new',
      'iar': '0',
    },
  ).query;
}

/// Fetches and caches the descriptor, then answers signed forms.
final class DouyuSigner {
  DouyuSigner({required this.client, required this.device, Clock? clock}) : _clock = clock ?? systemClock;

  final NetworkClient client;
  final DouyuDevice device;
  final Clock _clock;

  DouyuEncryptionDescriptor? _cached;
  int? _fetchedAtSeconds;

  /// The refresh in flight, so two rooms opening at once share one descriptor fetch instead of asking twice
  /// for a document the edge issues per device.
  Future<DouyuEncryptionDescriptor>? _refresh;

  Future<String> sign(String roomId, {int rate = -1, String cdn = '', bool forceRefresh = false}) async {
    final descriptor = await _descriptorFor(forceRefresh: forceRefresh);
    return douyuSignedForm(
      descriptor: descriptor,
      roomId: roomId,
      timestampSeconds: _nowSeconds(),
      deviceId: device.deviceId,
      rate: rate,
      cdn: cdn,
    );
  }

  Future<DouyuEncryptionDescriptor> _descriptorFor({bool forceRefresh = false}) async {
    final now = _nowSeconds();
    final cached = _cached;
    final fetchedAt = _fetchedAtSeconds;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        now - fetchedAt < kDouyuDescriptorMaxAgeSeconds &&
        cached.isUsable(nowSeconds: now)) {
      return cached;
    }
    final running = _refresh;
    // A caller that asks for a forced refresh must not be served the in-flight one it is trying to replace.
    if (!forceRefresh && running != null) {
      return running;
    }
    final refresh = _fetch();
    _refresh = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refresh, refresh)) {
        _refresh = null;
      }
    }
  }

  Future<DouyuEncryptionDescriptor> _fetch() async {
    final json = await client.getJson(
      kDouyuEncryptionEndpoint,
      queryParameters: <String, dynamic>{'did': device.deviceId},
      headers: device.headers(),
    );
    final data = jsonMap(json['data']);
    if (data == null) {
      throw const FormatException('Douyu encryption response carries no data object');
    }
    final descriptor = DouyuEncryptionDescriptor.fromJson(data);
    final now = _nowSeconds();
    if (!descriptor.isUsable(nowSeconds: now)) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    _cached = descriptor;
    _fetchedAtSeconds = now;
    return descriptor;
  }

  int _nowSeconds() => _clock().millisecondsSinceEpoch ~/ 1000;
}

/// The source id every douyu row carries. Like huya's, it is stored inside favourite and history rows, so
/// renaming it orphans them.
const String douyuSourceId = 'douyu.live';

/// The room list endpoints page about two dozen rows at a time and ignore a requested size.
const int kDouyuListPageSize = 24;

/// Douyu answers ints as ints on some endpoints and as decimal strings on others, and a missing flag here means
/// "not the live one" rather than "unstated" - which is why this site's reading returns 0 where the shared
/// [jsonInt] returns null.
int douyuInt(Object? value) => jsonInt(value) ?? 0;

/// A JSON object, or null when the field was absent or was not an object.
///
/// Every endpoint here wraps its payload one level down, and the failure a caller needs to hear about is
/// "the shape changed", not a cast exception from inside a widget.
Map<String, Object?>? douyuObject(Object? value) => jsonMap(value);

/// The rows of a list field, dropping anything that is not an object rather than failing the whole page.
List<Map<Object?, Object?>> douyuRows(Object? value) =>
    value is List ? value.whereType<Map<Object?, Object?>>().toList(growable: false) : const <Map<Object?, Object?>>[];

/// The two rows a live room is *not*: an offline room (`show_status`) and a recording loop (`videoLoop`),
/// plus the re-upload rows whose title announces itself as a replay.
bool douyuRoomPayloadIsLive(Map<Object?, Object?> room) {
  final name = '${room['room_name'] ?? ''}';
  return douyuInt(room['show_status']) == 1 && douyuInt(room['videoLoop']) != 1 && !name.startsWith('【回放】');
}

/// A `data.rl` row is a live room when its `type` is 1; other types are the directory's own filler.
bool douyuListRowIsLive(Map<Object?, Object?> row) => douyuInt(row['type']) == 1;

/// A search row is playable now when the anchor is live and the room is not a replay room (`roomType`).
bool douyuSearchRowIsLive(Map<Object?, Object?> row) => douyuInt(row['isLive']) == 1 && douyuInt(row['roomType']) == 0;

/// One room from a `data.rl` row, shared by the recommend page and a category page.
ContentSummary douyuRoomFromListRow(Map<Object?, Object?> row) {
  final roomId = '${row['rid'] ?? ''}';
  final name = '${row['rn'] ?? ''}'.trim();
  final nick = '${row['nn'] ?? ''}'.trim();
  final area = '${row['c2name'] ?? ''}'.trim();
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${row['rs16'] ?? ''}'),
    metadata: ContentMetadata(popularity: douyuInt(row['ol'])),
  );
}

/// One room from a `data.relateShow` search row.
ContentSummary douyuRoomFromSearchRow(Map<Object?, Object?> row) {
  final roomId = '${row['rid'] ?? ''}';
  final name = '${row['roomName'] ?? ''}'.trim();
  final nick = '${row['nickName'] ?? ''}'.trim();
  final area = '${row['cateName'] ?? ''}'.trim();
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${row['roomSrc'] ?? ''}'),
    // Search returns offline rooms too, and the row that says so is the only place that fact survives:
    // `description` would be a UI string, this is the field the contract has for a source's own statement.
    metadata: ContentMetadata(
      popularity: douyuInt(row['hot']),
      extra: <String, Object?>{'isLive': douyuSearchRowIsLive(row)},
    ),
  );
}

/// One room from the `betard/<roomId>` profile document, the only answer that states live status outright.
ContentSummary douyuRoomFromProfile(Map<Object?, Object?> room, {required String roomId}) {
  final name = '${room['room_name'] ?? ''}'.trim();
  final owner = '${room['owner_name'] ?? ''}'.trim();
  final area = '${room['second_lvl_name'] ?? ''}'.trim();
  final details = '${room['show_details'] ?? ''}'.trim();
  final business = room['room_biz_all'];
  final startedAt = douyuStartedAt(room['show_time']);
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: '${room['room_id'] ?? roomId}', kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (owner.isNotEmpty) owner, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${room['room_pic'] ?? ''}'),
    description: details.isEmpty ? null : details,
    metadata: ContentMetadata(
      popularity: business is Map ? douyuInt(business['hot']) : 0,
      // A room page says "已直播 2 小时", and the only honest source of that is the profile's own start time.
      extra: <String, Object?>{if (startedAt != null) 'startedAt': startedAt.toIso8601String()},
    ),
  );
}

/// A cover url, with `//host/path` (protocol-relative, which the search endpoint does return) made absolute.
String? douyuAbsoluteUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed.startsWith('http') ? trimmed : null;
}

/// When the broadcast began, from a unix-seconds field. Out-of-range values are read as "not stated": a room
/// that claims 1970 or 2087 is a field that meant something else.
DateTime? douyuStartedAt(Object? raw) {
  final seconds = jsonInt(raw);
  if (seconds == null || seconds <= 0) {
    return null;
  }
  final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  if (time.year < 2000 || time.year > 2100) {
    return null;
  }
  return time;
}

/// The playable url of one H5 play answer, or null when the answer states none.
///
/// `rtmp_live` has shipped two ways: the signed media path (which must be joined to `rtmp_url`/`flv_url`) and,
/// in current responses, a complete url. A complete one has to win, because prefixing a second absolute url
/// yields a syntactically valid input like `https://cdn/live/https://other/live.flv` that nothing can open;
/// handing back a bare CDN directory is what produced the "input stream address format" failures.
String? douyuPlayUrl(Map<String, Object?> data) {
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
  return null;
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
/// the enum has no member for it and merging the two is what platform-models.md §11 forbids.
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
