// Module: lib/src/bigo/bigo_api.dart
// Purpose: Bigo Live 的请求面:有限首页快照、网页 token 握手(jsonp + AES 信封)、studio 状态与 hls 租约、房间链接读法,
// 以及那条 m3u8 的分片保护变换。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the token envelope, the jsonp callback rules, the three-way access model and the HLS
// protection transform follow the v1-maintained Bigo line (origin/master lib/shared/platforms/bigo/). Fresh
// implementation against the v2 capability contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, bigo_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the room is the handle, not the number**. `bigo_id` is the addressable room; `room_id` is a broadcast id
//     that exceeds javascript's exact-integer range, so it is kept as **text** and never used as the public id.
//   * **the homepage is a finite snapshot**. The endpoint filled 20 rows when asked for 10, so the list this
//     source can page through is that block: the total is stated, and paging is slicing of what was verified
//     rather than a server-side pagination contract that was never observed.
//   * **gated is not offline**. `needLogin`, a password room and a paid room each answer `alive`, but v1's note is
//     kept: an access-gated `alive == 0` is not a verified offline observation, so the state stays unknown and the
//     restriction carries why a viewer cannot open it.
//   * **the token is a two-step jsonp handshake**. A server timestamp, then an AES-256-CBC envelope whose key is
//     derived by OpenSSL's EVP_BytesToKey from the site's bundle passphrase. The passphrase is a public website
//     constant - it authorises nothing about a viewer, which is why it is a code constant and not a setting.
//   * **an address that should not exist is a schema change**. A gated room shipping an `hls_src`, or a room the
//     site says is not alive shipping one, is refused rather than played: presence of a url is not permission.
//   * **the m3u8 may be protected**. The manifest can carry `#EXT-X-BIGO-WEB-PROTECTION:SEED=…`, and each
//     segment's first 376 bytes (two 188-byte TS packets, 16 bytes each) are XOR'd with a seeded xorshift. The
//     codec is here and tested; applying it needs a segment hook this platform's player path does not have yet.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String bigoSourceId = 'bigo.live';
const String bigoApiOrigin = 'https://ta.bigo.tv/official_website';
const String bigoSecurityOrigin = 'https://sec.bigo.sg/v1/webjs';
const String bigoWebOrigin = 'https://www.bigo.tv';

const String bigoUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const Map<String, String> bigoApiHeaders = <String, String>{
  'origin': bigoWebOrigin,
  'referer': '$bigoWebOrigin/',
  'user-agent': bigoUserAgent,
  'accept': 'application/json, text/javascript, */*; q=0.01',
  'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
  'x-requested-with': 'XMLHttpRequest',
};

/// The homepage block. The endpoint filled this many rows while asked for ten, so it is the server's number and
/// the number a caller's paging arithmetic is told.
const int bigoDirectoryServerRows = 20;

/// The one tab of the public web list this source can address.
const String bigoPublicDirectoryId = '72';

/// How long the snapshot is reused. It is one finite block, so every page of one scroll would otherwise refetch
/// and revalidate the same twenty rooms.
const Duration bigoDirectoryLifetime = Duration(seconds: 30);

/// The most rows a directory answer may carry before it is read as a changed endpoint rather than a list.
const int bigoDirectoryRowLimit = 500;

/// A bigo answer that is not the answer we asked for.
final class BigoFailure implements Exception {
  const BigoFailure(this.message, {this.code, this.apiCode, this.cause, this.missing = false});

  final String message;

  /// The http status, when there was one.
  final int? code;

  /// The envelope's own `code` / `resCode`, when the refusal came from inside a 200 answer.
  final int? apiCode;
  final Object? cause;

  /// "There is no such room." A fact about the handle, not an offline broadcast and not the service.
  final bool missing;

  @override
  String toString() =>
      'BigoFailure($message'
      '${code == null ? '' : ', http $code'}'
      '${apiCode == null ? '' : ', api $apiCode'}'
      '${cause == null ? '' : ': $cause'})';
}

/// What the site says stands between an anonymous viewer and this room.
enum BigoAccess { public, loginRequired, restricted }

/// One card of the homepage block.
final class BigoDirectoryCard {
  const BigoDirectoryCard({
    required this.siteId,
    required this.ownerId,
    required this.broadcastId,
    required this.sid,
    required this.title,
    required this.nickname,
    required this.locked,
    required this.roomFlag,
    this.cover,
    this.viewers,
  });

  final String siteId;
  final int ownerId;

  /// `room_id` as its **text** spelling. It is an int64 that javascript cannot hold exactly, and rounding it
  /// through a double would name a broadcast that does not exist.
  final String broadcastId;
  final int sid;
  final String title;
  final String nickname;
  final String? cover;
  final int? viewers;

  /// A password-locked card: the site says so, and only the room command says what else stands in the way.
  final bool locked;
  final int roomFlag;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: bigoSourceId, contentId: siteId, kind: ContentKind.liveRoom),
    // A homepage card is an on-air listing by construction; the room command is what contradicts it.
    state: LiveRoomState.live,
    title: title.isEmpty ? nickname : title,
    anchorName: nickname.isEmpty ? null : nickname,
    anchorId: '$ownerId',
    avatar: cover,
    cover: cover,
    area: 'Bigo Live',
    link: bigoRoomUrl(siteId),
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    restriction: locked ? LiveRestriction.private : null,
    streamId: broadcastId,
    danmakuPayload: <String, Object?>{'siteId': siteId, 'ownerId': ownerId, 'sid': sid},
    headers: const <String, String>{'user-agent': bigoUserAgent, 'referer': '$bigoWebOrigin/'},
    extra: <String, Object?>{'bigo.roomFlag': roomFlag, if (locked) 'bigo.locked': true},
  );
}

/// One room as the studio command described it.
final class BigoRoom {
  const BigoRoom({
    required this.requestedSiteId,
    required this.siteId,
    required this.ownerId,
    required this.access,
    required this.alive,
    required this.roomStatus,
    required this.roomType,
    this.password = false,
    this.roomId,
    this.nickname = '',
    this.title = '',
    this.category = '',
    this.avatar,
    this.snapshot = '',
    this.hls,
  });

  final String requestedSiteId;

  /// `clientBigoId`: the handle the site itself considers canonical for this room.
  final String siteId;
  final int ownerId;
  final BigoAccess access;

  /// The site's `alive` flag, read as a state only for a public room. `null` means the answer did not settle it.
  final bool? alive;

  /// `roomStatus` / `roomType`, kept as the site's raw numbers because their meaning is not published.
  final int roomStatus;
  final String roomType;

  /// The numeric room id the danmaku socket joins on. Distinct from [siteId] and from the broadcast id.
  final String? roomId;
  final String nickname;
  final String title;
  final String category;
  final String? avatar;
  final String? snapshot;

  /// `passRoom`: the site's own word for a password room. Kept apart from [access] because a room can be both
  /// login-gated and password-gated, and the reason shown to the viewer is the password.
  final bool password;

  /// The one hls address, when the site serves one.
  final Uri? hls;

  bool get isPublic => access == BigoAccess.public;

  /// On air is only ever claimed for a public room the site says is alive. Everything else is unknown, because
  /// "gated" and "ended" are different facts and the answer distinguishes them.
  LiveRoomState get state {
    if (!isPublic) {
      return alive == true ? LiveRoomState.live : LiveRoomState.unknown;
    }
    return switch (alive) {
      true => LiveRoomState.live,
      false => LiveRoomState.ended,
      null => LiveRoomState.unknown,
    };
  }

  LiveRestriction get restriction => switch (access) {
    // The anonymous path cannot satisfy an account requirement, which is what the site's own `needLogin` means.
    BigoAccess.loginRequired => LiveRestriction.private,
    BigoAccess.restricted => password ? LiveRestriction.private : LiveRestriction.paid,
    BigoAccess.public => hls == null ? LiveRestriction.unplayable : LiveRestriction.none,
  };

  LiveRoom toLiveRoom() {
    // The socket joins the numeric room, which only exists for a public room the site says is on air and that is
    // not behind an account this path cannot satisfy.
    final canChat = state == LiveRoomState.live && roomId != null && restriction != LiveRestriction.private;
    return LiveRoom(
      ref: ContentRef(sourceId: bigoSourceId, contentId: siteId, kind: ContentKind.liveRoom),
      state: state,
      title: title.isEmpty ? nickname : title,
      anchorName: nickname.isEmpty ? null : nickname,
      anchorId: '$ownerId',
      avatar: avatar,
      cover: (snapshot?.isNotEmpty ?? false) ? snapshot : avatar,
      area: category.isEmpty ? null : category,
      link: bigoRoomUrl(siteId),
      reportedStateCode: roomStatus,
      restriction: restriction,
      streamId: roomId,
      danmakuPayload: <String, Object?>{
        'ownerId': ownerId,
        if (canChat) 'siteId': siteId,
        if (canChat) 'roomId': roomId,
      },
      headers: const <String, String>{'user-agent': bigoUserAgent, 'referer': '$bigoWebOrigin/'},
      sitePayload: const <String, Object?>{},
      extra: <String, Object?>{
        'bigo.roomType': roomType,
        'bigo.access': access.name,
        if (requestedSiteId != siteId) 'bigo.requestedSiteId': requestedSiteId,
      },
    );
  }

  AnchorSummary toAnchorSummary() => AnchorSummary(
    ref: ContentRef(sourceId: bigoSourceId, contentId: '$ownerId', kind: ContentKind.anchor),
    name: nickname.isEmpty ? siteId : nickname,
    avatar: avatar,
    currentRoom: state == LiveRoomState.live
        ? ContentRef(sourceId: bigoSourceId, contentId: siteId, kind: ContentKind.liveRoom)
        : null,
  );
}

/// The room page for a handle.
String bigoRoomUrl(String siteId) => '$bigoWebOrigin/${bigoSiteId(siteId)}';

/// A room handle: the site's own `bigo_id` shape.
String bigoSiteId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.\-]{0,63}$').hasMatch(id)) {
    throw BigoFailure('not a bigo room handle: "$id"');
  }
  return id;
}

/// An owner or `sid` number. Beyond javascript's exact range the site's own ids stop being comparable, so an
/// answer that puts one there is read as an identity failure rather than as a room.
int bigoOwnerId(Object? value) {
  final id = jsonInt(value);
  if (id == null || id < 1 || id > 9007199254740991) {
    throw BigoFailure('not a bigo owner id: "$value"');
  }
  return id;
}

/// The handle in a bigo url, or null.
///
/// `bigo.tv/<handle>` and `bigo.tv/<locale>/<handle>` are the two shapes the site shares. The words the site uses
/// for its own pages are refused here: `live` is a path on the site, and treating it as someone's handle would
/// resolve a marketing page as a broadcast.
String? bigoRoomFromUri(Uri uri) {
  if (rawValueLengthExceeded(uri.toString())) {
    return null;
  }
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host != 'bigo.tv' && host != 'www.bigo.tv') {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  final candidate = switch (segments) {
    <String>[final String id] => id,
    <String>[final String locale, final String id] when RegExp(r'^[A-Za-z]{2}$').hasMatch(locale) => id,
    _ => null,
  };
  if (candidate == null || _reservedHandles.contains(candidate.toLowerCase())) {
    return null;
  }
  try {
    return bigoSiteId(candidate);
  } on BigoFailure {
    return null;
  }
}

const Set<String> _reservedHandles = <String>{'about', 'download', 'index', 'live', 'login', 'search', 'signup'};

bool rawValueLengthExceeded(String value) => value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value);

/// A handle from either a pasted url or a bare handle.
String? bigoHandleFromText(String raw) {
  final value = raw.trim();
  if (value.isEmpty || rawValueLengthExceeded(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    return bigoRoomFromUri(uri);
  }
  try {
    return bigoSiteId(value);
  } on BigoFailure {
    return null;
  }
}

/// The jsonp envelope: the callback the caller asked for, or nothing at all.
///
/// Checking the name is not ceremony. A cached or error page answers with a *different* callback, and stripping
/// whatever prefix happens to be there would execute the site's error text as our answer.
Map<String, Object?> bigoJsonp(String source, String callback) {
  final prefix = '$callback(';
  final trimmed = source.trim();
  if (!trimmed.startsWith(prefix) || !trimmed.endsWith(');')) {
    throw const BigoFailure('the token answer is not the jsonp we asked for');
  }
  try {
    return jsonMap(jsonDecode(trimmed.substring(prefix.length, trimmed.length - 2))) ??
        (throw const BigoFailure('the token answer is not an object'));
  } on FormatException catch (error) {
    throw BigoFailure('the token answer is not readable json', cause: error);
  }
}

/// A jsonp callback name, validated before it is put in a url.
String bigoCallback(Object? raw) {
  final value = raw is String ? raw : '';
  if (!RegExp(r'^jsonp[A-Za-z0-9_]{1,96}$').hasMatch(value)) {
    throw BigoFailure('not a jsonp callback this source asked for: "$value"');
  }
  return value;
}

/// The envelope `code` / `resCode` check for the two web endpoints.
Map<String, Object?> bigoSucceed(Map<String, Object?> envelope) {
  final code = jsonInt(envelope['code']);
  if (code == null) {
    throw const BigoFailure('the answer carries no code');
  }
  if (code != 0) {
    throw BigoFailure('the api refused the request', apiCode: code, missing: code == 404);
  }
  return jsonMap(envelope['data']) ?? const <String, Object?>{};
}

/// The homepage block.
///
/// Every row is validated, and one unusable row fails the whole page on purpose: this list is the finite snapshot
/// the search path filters, so a page that quietly dropped its broken rows would be reported as "no such streamer"
/// for someone who is actually listed.
List<BigoDirectoryCard> bigoDirectory(Object? value) {
  final envelope = bigoSucceed(jsonMap(value) ?? const <String, Object?>{});
  final resCode = envelope['resCode'];
  if (resCode is! String) {
    throw const BigoFailure('the directory answer carries no resCode');
  }
  if (resCode != '0') {
    throw BigoFailure('the directory refused the request', apiCode: int.tryParse(resCode));
  }
  final rows = envelope['data'];
  if (rows is! List || rows.isEmpty || rows.length > bigoDirectoryRowLimit) {
    throw const BigoFailure('the directory block is empty or unreasonably long');
  }
  final handles = <String>{};
  final owners = <int>{};
  final cards = <BigoDirectoryCard>[];
  for (final raw in rows) {
    final item = jsonMap(raw);
    if (item == null) {
      throw const BigoFailure('a directory row is not an object');
    }
    final siteId = bigoSiteId('${item['bigo_id'] ?? ''}');
    final owner = bigoOwnerId(item['owner']);
    final broadcast = jsonInt(item['room_id']);
    if (!handles.add(siteId.toLowerCase())) {
      throw BigoFailure('the directory repeats the handle $siteId');
    }
    if (!owners.add(owner)) {
      throw BigoFailure('the directory lists one owner twice');
    }
    if (broadcast == null || broadcast < 1) {
      throw BigoFailure('the row for $siteId carries no usable broadcast id');
    }
    final viewers = jsonInt(item['user_count']);
    cards.add(
      BigoDirectoryCard(
        siteId: siteId,
        ownerId: owner,
        // Kept as the int64's text spelling, never as a double.
        broadcastId: '$broadcast',
        sid: bigoOwnerId(item['sid']),
        title: '${item['room_topic'] ?? ''}'.trim(),
        nickname: '${item['nick_name'] ?? ''}'.trim(),
        cover: bigoPicture(item['cover_m']),
        viewers: viewers != null && viewers >= 0 ? viewers : null,
        locked: bigoFlag(item['is_locked']),
        roomFlag: jsonInt(item['room_flag']) ?? 0,
      ),
    );
  }
  return List<BigoDirectoryCard>.unmodifiable(cards);
}

/// `is_locked` and the other 0/1 flags the site ships as numbers.
bool bigoFlag(Object? raw) {
  final value = jsonInt(raw);
  if (value != 0 && value != 1) {
    throw BigoFailure('a bigo flag arrived as "$raw"');
  }
  return value == 1;
}

/// The studio status: who the room is, and what it says stands between the viewer and it.
BigoRoom bigoStatus(Object? value, {required String siteId, int? expectedOwnerId}) {
  final requested = bigoSiteId(siteId);
  final data = bigoSucceed(jsonMap(value) ?? const <String, Object?>{});
  final owner = bigoOwnerId(data['uid']);
  if (expectedOwnerId != null && owner != expectedOwnerId) {
    throw BigoFailure('the studio answer belongs to $owner while the listing said $expectedOwnerId');
  }
  final needLogin = data['needLogin'];
  if (needLogin is! bool) {
    throw const BigoFailure('the studio answer carries no needLogin flag');
  }
  final passRoom = data['passRoom'] is bool ? data['passRoom'] as bool : false;
  final paid = data['isPaidShow'];
  final paidText = paid == null ? '' : '${paid}'.trim();
  if (!const <String>{'', '0', '1'}.contains(paidText)) {
    throw BigoFailure('the studio answer reports payment as "$paid"');
  }
  final alive = jsonInt(data['alive']);
  if (alive != 0 && alive != 1) {
    throw BigoFailure('the studio answer reports alive as "${data['alive']}"');
  }
  final canonical = bigoSiteId('${data['clientBigoId'] ?? requested}');
  if (canonical.toLowerCase() != requested.toLowerCase()) {
    throw BigoFailure('the studio answer is about $canonical while asking about $requested');
  }
  final access = switch ((needLogin, passRoom || paidText == '1')) {
    (true, _) => BigoAccess.loginRequired,
    (_, true) => BigoAccess.restricted,
    _ => BigoAccess.public,
  };
  return BigoRoom(
    requestedSiteId: requested,
    siteId: canonical,
    ownerId: owner,
    access: access,
    // A gated answer's `alive` is not an observation of an ended broadcast, so it is kept out of the state and
    // only the restriction carries what the site actually said.
    alive: access == BigoAccess.public ? alive == 1 : null,
    roomStatus: jsonInt(data['roomStatus']) ?? 0,
    roomType: '${data['roomType'] ?? ''}'.trim(),
    password: passRoom,
    nickname: '${data['nick_name'] ?? ''}'.trim(),
    title: '${data['roomTopic'] ?? ''}'.trim(),
    category: '${data['gameTitle'] ?? ''}'.trim(),
    avatar: bigoPicture(data['avatar']),
    snapshot: bigoPicture(data['snapshot']),
    roomId: bigoNumericRoomId(data['roomId']),
  );
}

/// The studio answer **with** the media lease.
BigoRoom bigoStudioRoom(Object? value, {required String siteId, int? expectedOwnerId}) {
  final room = bigoStatus(value, siteId: siteId, expectedOwnerId: expectedOwnerId);
  final data = jsonMap(jsonMap(value)?['data']) ?? const <String, Object?>{};
  final rawHls = data['hls_src'];
  final text = rawHls == null ? '' : '${rawHls}'.trim();
  Uri? hls;
  if (text.isNotEmpty) {
    hls = bigoHlsUri(text);
    // Two shapes that must not coexist, kept from v1: a gated room does not get to ship an address we could open,
    // and a room the site says is not alive does not get to ship a live one. Either is a changed endpoint.
    if (!room.isPublic) {
      throw const BigoFailure('a gated room answered with a playable address');
    }
    if (room.alive == false) {
      throw const BigoFailure('a room the site says is not broadcasting answered with an address');
    }
  }
  return BigoRoom(
    requestedSiteId: room.requestedSiteId,
    siteId: room.siteId,
    ownerId: room.ownerId,
    access: room.access,
    alive: room.alive,
    roomStatus: room.roomStatus,
    roomType: room.roomType,
    password: room.password,
    roomId: room.roomId,
    nickname: room.nickname,
    title: room.title,
    category: room.category,
    avatar: room.avatar,
    snapshot: room.snapshot,
    hls: hls,
  );
}

String? bigoNumericRoomId(Object? raw) {
  final value = raw == null ? '' : '${raw}'.trim();
  if (value.isEmpty || value == '0') {
    return null;
  }
  if (!RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(value)) {
    throw const BigoFailure('the studio answer carries an unreadable numeric room id');
  }
  return value;
}

/// A picture url, or null. Anything that is not an absolute http(s) address with a host is dropped rather than
/// rendered as a broken tile.
String? bigoPicture(Object? raw) {
  final value = raw == null ? '' : '${raw}'.trim();
  if (value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }
  return uri.toString();
}

/// The lease address. https, a host, no credentials or fragment, and the manifest's own extension.
Uri bigoHlsUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.toLowerCase().endsWith('.m3u8')) {
    throw const BigoFailure('the studio answer carries an address this path will not open');
  }
  return uri;
}

/// The site's own web-token envelope.
///
/// AES-256-CBC with a key and iv derived by OpenSSL's EVP_BytesToKey (md5, one iteration per block) from a
/// passphrase baked into the site's published javascript bundle, base64'd behind the `Salted__` prefix. The
/// passphrase is a protocol constant of the website, not account material: it proves nothing about who is asking,
/// which is why this yields a public token rather than a logged-in one.
final class BigoTokenCodec {
  const BigoTokenCodec._();

  static const String _passphrase = 'undefinedval0x01';

  /// `data` for the status call. [salt] and [randomHex] exist so a test can pin one envelope; production leaves
  /// them null and gets a fresh cryptographic random each time.
  static String buildData(String timestamp, {Uint8List? salt, String? randomHex, Random? random}) {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(timestamp)) {
      throw BigoFailure('the token timestamp is not a number of seconds: "$timestamp"');
    }
    final source = random ?? Random.secure();
    final actualSalt = salt ?? Uint8List.fromList(List<int>.generate(8, (_) => source.nextInt(256)));
    if (actualSalt.length != 8) {
      throw const BigoFailure('the token salt is not 8 bytes');
    }
    final nonce = randomHex ?? List<String>.generate(32, (_) => source.nextInt(16).toRadixString(16)).join();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce)) {
      throw const BigoFailure('the token nonce is not 32 hex digits');
    }
    final payload = utf8.encode(
      jsonEncode(<String, String>{
        'dr': nonce,
        'business': 'bigolive-video',
        'scene': '',
        'at_time': timestamp,
        'ver': '2.0',
      }),
    );
    final (Uint8List key, Uint8List iv) = _evpBytesToKey(
      Uint8List.fromList(utf8.encode(_passphrase)),
      actualSalt,
      keyLength: 32,
      ivLength: 16,
    );
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return base64Encode(<int>[
      ...ascii.encode('Salted__'),
      ...actualSalt,
      ...cipher.process(Uint8List.fromList(payload)),
    ]);
  }

  static (Uint8List, Uint8List) _evpBytesToKey(
    Uint8List password,
    Uint8List salt, {
    required int keyLength,
    required int ivLength,
  }) {
    final output = BytesBuilder(copy: false);
    Uint8List previous = Uint8List(0);
    while (output.length < keyLength + ivLength) {
      previous = Uint8List.fromList(md5.convert(<int>[...previous, ...password, ...salt]).bytes);
      output.add(previous);
    }
    final bytes = output.takeBytes();
    return (Uint8List.sublistView(bytes, 0, keyLength), Uint8List.sublistView(bytes, keyLength, keyLength + ivLength));
  }
}

/// Bigo's public-web manifest protection.
///
/// A manifest can carry `#EXT-X-BIGO-WEB-PROTECTION:SEED=<n>`; each media segment's first 376 bytes are then the
/// two leading 188-byte TS packets with their first 16 bytes XOR'd by a seeded xorshift. Applying
/// [transformSegment] to itself restores the source, which is why the same function is both the decode and the
/// encode.
///
/// The platform has no segment-transform hook on the playback path yet, so this is what the recorder and a future
/// proxy will need; a ticket built without it would feed the kernel protected bytes. See
/// docs/roadmap/packages-rebuild-progress.md.
final class BigoHlsProtection {
  const BigoHlsProtection._();

  static final RegExp _tag = RegExp(
    r'^#EXT-X-BIGO-WEB-PROTECTION:SEED=([0-9]+)\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  static const int _packetSize = 188;
  static const int _prefixBytes = 16;
  static const int _protectedBytes = _packetSize * 2;

  /// The seed, or null when this manifest is not protected. Out of range is a schema change, not "no seed".
  static int? seedFromManifest(String manifest) {
    final match = _tag.firstMatch(manifest);
    if (match == null) {
      return null;
    }
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 0 || value > 0xffffffff) {
      throw const BigoFailure('the manifest protection seed is out of range');
    }
    return value;
  }

  static bool isProtected(String manifest) => _tag.hasMatch(manifest);

  static Uint8List transformSegment(List<int> source, int seed) {
    if (seed < 0 || seed > 0xffffffff) {
      throw const BigoFailure('the segment seed is out of range');
    }
    if (source.length < _protectedBytes + _prefixBytes) {
      throw const BigoFailure('the segment is too short to carry the protection prefix');
    }
    final packets = Uint8List.fromList(source);
    for (var packet = 0; packet < 2; packet++) {
      var state = (seed ^ ((packet + 1) * 2654435769)) & 0xffffffff;
      if (state == 0) {
        state = 1831565813;
      }
      final offset = packet * _packetSize;
      for (var index = 0; index < _prefixBytes; index++) {
        state = (state ^ ((state << 13) & 0xffffffff)) & 0xffffffff;
        state = (state ^ (state >> 17)) & 0xffffffff;
        state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;
        var mask = state & 0xff;
        if (mask == 0) {
          mask = 165;
        }
        packets[offset + index] ^= mask;
      }
    }
    return packets;
  }
}

/// The bigo web client.
final class BigoApi {
  BigoApi({NetworkClient? client, Clock? clock, String? cookie, String Function()? callbackFactory})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock,
      _cookie = (cookie ?? '').trim(),
      _callbackFactory = callbackFactory ?? _timestampCallback;

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;

  /// A pasted account cookie. The public token handshake is anonymous, so this is the only way a login-gated room
  /// can be answered at all - and it stays the operator's, never stored in a room.
  final String _cookie;
  final String Function() _callbackFactory;

  List<BigoDirectoryCard>? _snapshot;
  DateTime? _snapshotAt;
  Future<List<BigoDirectoryCard>>? _snapshotInFlight;

  static String _timestampCallback() {
    final now = DateTime.now();
    return 'jsonpb${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000000}';
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The transport's failure names, re-worded as this site's.
  ///
  /// A 404 has to arrive as [BigoFailure.missing], because that is the difference between "no such room" and
  /// "the service is down" - and a search that reads the second as the first silently loses every room a viewer
  /// typed in for, while a follow list that reads the first as the second forgets a live streamer.
  Future<T> _site<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on NetworkFailure catch (error) {
      throw switch (error.kind) {
        NetworkFailureKind.notFound => BigoFailure('no such room', code: error.statusCode, missing: true),
        NetworkFailureKind.forbidden => BigoFailure(
          'the site asked for an account this path does not have',
          code: error.statusCode,
        ),
        NetworkFailureKind.rateLimited => BigoFailure('the site is rate-limiting this client', code: error.statusCode),
        NetworkFailureKind.cancelled => BigoFailure('the request was cancelled', code: error.statusCode),
        _ => BigoFailure('the endpoint did not answer', code: error.statusCode, cause: error),
      };
    }
  }

  Map<String, String> get _headers => <String, String>{...bigoApiHeaders, if (_cookie.isNotEmpty) 'cookie': _cookie};

  /// The homepage block, reused for the length of one scroll.
  ///
  /// The cache is a single shared request: two surfaces asking at once get one fetch each, and a failure is not
  /// cached, so one抖动 does not pin an empty list for the life of the process.
  Future<List<BigoDirectoryCard>> directory() {
    final at = _snapshotAt;
    final cached = _snapshot;
    final now = _clock();
    if (cached != null && at != null && now.difference(at) < bigoDirectoryLifetime) {
      return Future<List<BigoDirectoryCard>>.value(cached);
    }
    final running = _snapshotInFlight;
    if (running != null) {
      return running;
    }
    late final Future<List<BigoDirectoryCard>> operation;
    operation = _fetchDirectory()
        .then((List<BigoDirectoryCard> cards) {
          _snapshot = cards;
          _snapshotAt = _clock();
          return cards;
        })
        .whenComplete(() {
          if (identical(_snapshotInFlight, operation)) {
            _snapshotInFlight = null;
          }
        });
    _snapshotInFlight = operation;
    return operation;
  }

  Future<List<BigoDirectoryCard>> _fetchDirectory() async {
    final response = await _site(
      () => _client.getText(
        '$bigoApiOrigin/OInterfaceWeb/vedioList/$bigoPublicDirectoryId',
        headers: _headers,
        queryParameters: <String, String>{'tabType': '00', 'fetchNum': '10', 'lang': 'en', 'countryCode': 'US'},
      ),
    );
    return bigoDirectory(_decode(response, 'directory'));
  }

  /// Status only, no media and no token handshake: what a follow-list poll needs, in one request.
  Future<BigoRoom> status(String siteId, {int? expectedOwnerId}) async {
    final handle = bigoSiteId(siteId);
    final response = await _client.postForm('$bigoApiOrigin/studio/getInternalStudioInfo', <String, Object?>{
      'siteId': handle,
      'supportHevc': '0',
    }, headers: _headers);
    return bigoStatus(_decode(response, 'studio'), siteId: handle, expectedOwnerId: expectedOwnerId);
  }

  /// The room with its lease. Costs the token handshake first: the site issues `hls_src` only alongside a current
  /// public web token.
  Future<BigoRoom> room(String siteId, {int? expectedOwnerId}) async {
    final handle = bigoSiteId(siteId);
    final token = await _webToken();
    final response = await _site(
      () => _client.postForm(
        '$bigoApiOrigin/studio/getInternalStudioInfo',
        const <String, Object?>{},
        headers: _headers,
        queryParameters: <String, String>{'siteId': handle, 'verify': '', 'token': token},
      ),
    );
    return bigoStudioRoom(_decode(response, 'studio'), siteId: handle, expectedOwnerId: expectedOwnerId);
  }

  Future<String> _webToken() async {
    final timestampCallback = bigoCallback(_callbackFactory());
    final timestamp = bigoJsonp(
      await _text('$bigoSecurityOrigin/t', <String, String>{'callback': timestampCallback}),
      timestampCallback,
    );
    if (jsonInt(timestamp['code']) != 0) {
      throw BigoFailure('the timestamp call refused', apiCode: jsonInt(timestamp['code']));
    }
    final seconds = '${timestamp['time'] ?? ''}'.trim();
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(seconds)) {
      throw const BigoFailure('the timestamp call answered without a usable time');
    }
    final statusCallback = bigoCallback(_callbackFactory());
    final status = bigoJsonp(
      await _text('$bigoSecurityOrigin/status', <String, String>{
        'callback': statusCallback,
        'data': BigoTokenCodec.buildData(seconds),
      }),
      statusCallback,
    );
    final token = '${status['token'] ?? ''}'.trim();
    if (token.isEmpty || token.length > 4096 || RegExp(r'[\x00-\x20\x7f]').hasMatch(token)) {
      throw const BigoFailure('the token call answered without a token we can put in a url');
    }
    return token;
  }

  Future<String> _text(String url, Map<String, String> query) async {
    final response = await _site(() => _client.getText(url, headers: _headers, queryParameters: query));
    _expect(response, 'token');
    return response.body;
  }

  Object? _decode(TextResponse response, String what) {
    _expect(response, what);
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw BigoFailure('the $what answer is not readable json', cause: error);
    }
  }

  void _expect(TextResponse response, String what) {
    final failure = switch (response.statusCode) {
      200 => null,
      401 || 403 => 'the site asked for an account this path does not have',
      404 => 'no such room',
      429 => 'the site is rate-limiting this client',
      _ when response.statusCode >= 500 => 'the site failed the request',
      _ => 'the $what endpoint did not answer',
    };
    if (failure != null) {
      throw BigoFailure(failure, code: response.statusCode, missing: response.statusCode == 404);
    }
  }
}
