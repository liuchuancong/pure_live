// Module: lib/src/soop/soop_api.dart
// Purpose: SOOP(原 AfreecaTV)的请求面:分类表与分类清单、首页推荐、player_live_api 的频道与业务码、
// 按档位签名的取流地址,以及聊天端点的 TLS 端口推导。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the PC/mobile viewer split, the result-code meanings, the return-type mapping, the
// broad_key shape and the chat port rule follow the v1-maintained SOOP line (origin/master
// lib/shared/platforms/soop/soop_site.dart). Fresh implementation against the v2 capability contracts, not a file
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, soop_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the business code decides what is known**. `RESULT: 1` is a channel, `0` is the site's explicit "no live
//     now", `-2` is a banned account, and **anything else is a session or shape problem that must not be read as
//     offline** - that is the difference between a follow list polling on and one that quietly gave up.
//   * **the audience is split across platforms**. `current_view_cnt` is PC-only; the concurrent audience is
//     `total_view_cnt`/`view_cnt` or the sum of the explicit PC and mobile fields. An explicit zero stays zero and
//     an unstated count stays null.
//   * **the tier name is the word the play request speaks**. `bps` only orders inside one tier, and the source
//     preset is occasionally returned with a missing or zero bitrate - which must not sort it below the
//     transcoded variants.
//   * **the chat socket's TLS port is one above the plain port**, and the host may have to be rebuilt from the
//     chat IP (`chat-<hex-octets>.sooplive.co.kr`). Connecting WSS to the unmodified port stalls in the TLS
//     handshake, so the +1 is protocol knowledge, not a typo.
//   * **the broadcast number is not the room**. v1 stored `BNO` in the room's user field; this port keeps the
//     streamer id as the ref and puts `BNO` in `streamId`, because a favourite whose user id changes every
//     broadcast is a favourite that cannot be compared to itself.

import 'dart:convert';

import 'package:html/parser.dart' show parseFragment;
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String soopSourceId = 'soop.live';
const String soopWebOrigin = 'https://www.sooplive.co.kr';
const String soopSearchOrigin = 'https://sch.sooplive.co.kr';
const String soopLiveOrigin = 'https://live.sooplive.co.kr';
const String soopChatDomain = 'sooplive.co.kr';

const String soopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// The headers the web client sends. The site checks the origin pair, and a session cookie is only present when
/// an operator supplied one - soop's anonymous answers for adult or account-gated rooms are the site's call.
Map<String, String> soopHeaders({String cookie = ''}) => <String, String>{
  'accept': '*/*',
  'user-agent': soopUserAgent,
  'origin': soopWebOrigin,
  'referer': '$soopWebOrigin/',
  'sec-fetch-dest': 'empty',
  'sec-fetch-mode': 'cors',
  'sec-fetch-site': 'same-site',
  if (cookie.isNotEmpty) 'cookie': cookie,
};

/// The business codes the player API answers with.
const int soopResultLive = 1;
const int soopResultNoLive = 0;
const int soopResultBanned = -2;

/// The category table's page size, and the width the listings default to.
const int soopCategoryPageSize = 120;
const int soopListPageSize = 10;
const int soopListPageSizeLimit = 60;

/// The tier ranks the site's own names imply. A name outside this table sorts by its stated bitrate alone.
const Map<String, int> soopTierRanks = <String, int>{
  'original': 6,
  'origin': 6,
  'source': 6,
  'master': 5,
  'uhd': 5,
  'fullhd': 4,
  'fhd': 4,
  'hd': 3,
  'sd': 2,
  'normal': 2,
  'low': 1,
  'ld': 1,
};

/// A soop answer that is not the answer we asked for.
final class SoopFailure implements Exception {
  const SoopFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;

  /// The http status, or the site's own business code when that is what refused us.
  final int? code;
  final Object? cause;

  /// "No such channel." Not an offline room and not the service.
  final bool missing;

  @override
  String toString() => 'SoopFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One tier of the channel's preset list.
final class SoopQuality {
  const SoopQuality({required this.name, required this.rank, required this.bitrateBps});

  /// The site's own row name (`Original`, `HD`, …). It is both the label the viewer sees and the string the play
  /// request carries back - the assignment signs `…-common-Original-hls`, and a lower-cased spelling asks for a
  /// tier the answer never named. Asks are matched against it case-insensitively because the dedupe keeps only the
  /// first spelling a channel used.
  final String name;

  /// Tier rank then bitrate, so a preset with no stated bitrate still sits with its tier.
  final int rank;

  /// `bps`, and only when the row stated one.
  final int? bitrateBps;
}

/// A channel as the player API described it.
final class SoopChannel {
  const SoopChannel({
    required this.roomId,
    required this.resultCode,
    required this.isLiving,
    required this.banned,
    this.broadcastId = '',
    this.title = '',
    this.nick = '',
    this.area = '',
    this.viewers,
    this.cover = '',
    this.avatar = '',
    this.chatUrl = '',
    this.chatNo = '',
    this.streamHost = '',
    this.cdn = '',
    this.qualities = const <SoopQuality>[],
  });

  final String roomId;

  /// `CHANNEL.RESULT`, kept as the number it was.
  final int resultCode;
  final bool isLiving;
  final bool banned;

  /// `BNO` - this broadcast's number. Per broadcast, so it is a stream id and not a ref.
  final String broadcastId;
  final String title;
  final String nick;
  final String area;

  /// The concurrent audience, with the PC/mobile split already resolved. Null means the answer stated none.
  final int? viewers;
  final String cover;
  final String avatar;

  /// The chat socket and its room number (`CHATNO`).
  final String chatUrl;
  final String chatNo;

  /// `RMD` - the media host the tier assignment is asked from.
  final String streamHost;
  final String cdn;
  final List<SoopQuality> qualities;

  bool get isPlayable => isLiving && broadcastId.isNotEmpty && streamHost.isNotEmpty;

  LiveRoom toLiveRoom({String cookie = ''}) => LiveRoom(
    ref: ContentRef(sourceId: soopSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    state: switch ((isLiving, banned)) {
      (true, _) => LiveRoomState.live,
      (_, true) => LiveRoomState.ended,
      // A RESULT we did not understand is the site not telling, which is not the same claim as "ended".
      _ => resultCode == soopResultNoLive ? LiveRoomState.ended : LiveRoomState.unknown,
    },
    title: title,
    anchorName: nick.isEmpty ? null : nick,
    avatar: avatar.isEmpty ? null : avatar,
    cover: cover.isEmpty ? null : cover,
    area: area.isEmpty ? null : area,
    link: '$soopWebOrigin/$roomId',
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    restriction: restriction,
    reportedStateCode: resultCode,
    streamId: broadcastId.isEmpty ? null : broadcastId,
    danmakuPayload: <String, Object?>{
      if (isLiving && chatUrl.isNotEmpty) 'url': chatUrl,
      if (isLiving && chatNo.isNotEmpty) 'chatNo': chatNo,
      'roomId': roomId,
    },
    headers: soopHeaders(cookie: cookie),
    sitePayload: <String, Object?>{
      if (streamHost.isNotEmpty) 'rmd': streamHost,
      if (cdn.isNotEmpty) 'cdn': cdn,
      if (broadcastId.isNotEmpty) 'bno': broadcastId,
    },
    extra: <String, Object?>{if (banned) 'soop.banned': true},
  );

  LiveRestriction? get restriction {
    if (banned) {
      return LiveRestriction.unplayable;
    }
    if (!isLiving) {
      return null;
    }
    return isPlayable && qualities.isNotEmpty ? LiveRestriction.none : LiveRestriction.unplayable;
  }
}

/// A streamer id: what the site puts in its urls. Kept permissive on case because the answers lower-case it
/// themselves and an id we could not match would look like a channel that does not exist.
String soopRoomId(String value) {
  final id = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9]{2,20}$').hasMatch(id)) {
    throw SoopFailure('not a soop channel id: "$value"');
  }
  return id;
}

/// The channel id in a soop url, or null.
String? soopRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      !const <String>{'sooplive.co.kr', 'www.sooplive.co.kr', 'play.sooplive.co.kr'}.contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length != 1) {
    return null;
  }
  try {
    return soopRoomId(segments.single);
  } on SoopFailure {
    return null;
  }
}

/// The channel's own picture address, built the way the site's page does.
String soopAvatarUrl(String roomId) {
  final id = roomId.trim();
  if (id.length < 2) {
    return '';
  }
  return 'https://stimg.$soopChatDomain/LOGO/${id.substring(0, 2)}/$id/m/$id.webp';
}

/// A picture address: protocol-relative normalised, nothing else rewritten.
String soopImage(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty) {
    return '';
  }
  return value.startsWith('//') ? 'https:$value' : value;
}

/// Text the site stores with html entities in it.
String soopDisplay(Object? raw) {
  final value = raw is String ? raw.trim() : (raw == null ? '' : '${raw}'.trim());
  if (value.isEmpty || !value.contains('&')) {
    return value;
  }
  return (parseFragment(value).text ?? value).trim();
}

/// The concurrent audience, across the PC/mobile split.
///
/// `total_view_cnt` / `view_cnt` / `VIEW_CNT` are the site's own combined figures; when only the per-platform
/// pair is present the two are added. An explicit zero is a stated zero, and a field that never appeared is null
/// - the first renders as "0 viewers" and the second as nothing.
int? soopViewers(Map<String, Object?> row) {
  int? explicitZero;
  int? positive(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null' || !RegExp('[0-9]').hasMatch(text)) {
      return null;
    }
    final parsed = int.tryParse(text.replaceAll(',', '').replaceAll('，', ''));
    if (parsed == null) {
      return null;
    }
    if (parsed == 0) {
      explicitZero ??= 0;
    }
    return parsed > 0 ? parsed : null;
  }

  for (final value in <Object?>[row['total_view_cnt'], row['view_cnt'], row['VIEW_CNT']]) {
    if (positive(value) case final int count) {
      return count;
    }
  }
  for (final (Object? pc, Object? mobile) in <(Object?, Object?)>[
    (row['pc_view_cnt'], row['mobile_view_cnt']),
    (row['current_view_cnt'], row['m_current_view_cnt']),
  ]) {
    final left = _intValue(pc);
    final right = _intValue(mobile);
    if (left == null && right == null) {
      continue;
    }
    final total = (left ?? 0) + (right ?? 0);
    if (total > 0) {
      return total;
    }
    explicitZero ??= 0;
  }
  return explicitZero;
}

int? _intValue(Object? raw) {
  final text = '${raw ?? ''}'.trim().replaceAll(',', '');
  return text.isEmpty ? null : int.tryParse(text);
}

/// The preset list, minus the automatic row.
///
/// `auto` is the player's own decision and not a tier a viewer can be asked to choose; the name is kept in the
/// site's own spelling because that is the string the play request has to carry back.
List<SoopQuality> soopQualities(Object? presets) {
  if (presets is! List) {
    return const <SoopQuality>[];
  }
  final byIdentity = <String, SoopQuality>{};
  for (final raw in presets) {
    final row = jsonMap(raw);
    final name = '${row?['name'] ?? ''}'.trim();
    if (row == null || name.isEmpty || name.toLowerCase() == 'auto') {
      continue;
    }
    final bitrate = jsonInt(row['bps']);
    byIdentity.putIfAbsent(
      // Duplicated in another case is the same tier, so the dedupe key is lower-cased while the name that goes
      // back to the site keeps its spelling.
      name.toLowerCase(),
      () => SoopQuality(
        name: name,
        bitrateBps: bitrate != null && bitrate > 0 ? bitrate : null,
        rank: soopTierSort(name, bitrate ?? 0),
      ),
    );
  }
  return byIdentity.values.toList(growable: false)
    ..sort((SoopQuality left, SoopQuality right) => right.rank.compareTo(left.rank));
}

/// The menu weight: the tier the name names, with the bitrate only as the tie-break inside it.
int soopTierSort(String rawName, int bitrateBps) {
  final name = rawName.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');
  final rank = soopTierRanks[name] ?? 0;
  return rank == 0 ? bitrateBps : rank * 100000000 + bitrateBps.clamp(0, 99999999);
}

/// The `return_type` the assignment endpoint wants for this cdn family.
String soopReturnType(String cdn) {
  if (cdn.contains('gs_cdn')) {
    return 'gs_cdn_pc_web';
  }
  if (cdn.contains('lg_cdn')) {
    return 'lg_cdn_pc_web';
  }
  return cdn;
}

/// The assignment url. The trailing slash on `RMD` is optional in the answer and required in the request.
Uri soopAssignUri(String streamHost) {
  final host = streamHost.trim();
  final normalized = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  final uri = Uri.tryParse(normalized);
  if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
    throw SoopFailure('the channel named an unusable media host: "$streamHost"');
  }
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  return uri.replace(path: '${path}broad_stream_assign.html');
}

/// The `broad_key` for one tier of one broadcast.
String soopBroadKey(String broadcastId, String tierName) => '$broadcastId-common-$tierName-hls';

/// The chat socket address.
///
/// The HTTPS player uses the port **after** the plain one the answer names - connecting wss to the unmodified
/// port stalls in the TLS handshake. When the answer gives no host, the site's own naming scheme rebuilds it from
/// the chat IPv4 as `chat-<hex><hex><hex><hex>.sooplive.co.kr`.
String soopChatUrl(Map<String, Object?> channel, String roomId) {
  final room = soopRoomId(roomId);
  var host = '${channel['CHDOMAIN'] ?? ''}'.trim();
  if (host.isEmpty) {
    host = soopChatHostFromIp('${channel['CHIP'] ?? ''}');
  }
  final plainPort = jsonInt(channel['CHPT']);
  if (host.isEmpty || plainPort == null || plainPort < 1 || plainPort >= 65535) {
    throw const SoopFailure('the channel answer carries no usable chat endpoint');
  }
  return Uri(scheme: 'wss', host: host, port: plainPort + 1, pathSegments: <String>['Websocket', room]).toString();
}

String soopChatHostFromIp(String rawIp) {
  final octets = rawIp.trim().split('.');
  if (octets.length != 4) {
    return '';
  }
  final parts = <String>[];
  for (final octet in octets) {
    final value = int.tryParse(octet);
    if (value == null || value < 0 || value > 255) {
      return '';
    }
    parts.add(value.toRadixString(16).padLeft(2, '0'));
  }
  return 'chat-${parts.join().toUpperCase()}.$soopChatDomain';
}

/// The channel answer, read from a player API response.
SoopChannel soopChannel(Object? raw, {required String askedRoomId, DateTime? capturedAt}) {
  final root = jsonMap(raw);
  if (root == null) {
    throw const SoopFailure('the player answer is not an object');
  }
  final channel = jsonMap(root['CHANNEL']);
  if (channel == null) {
    throw const SoopFailure('the player answer carries no CHANNEL block');
  }
  final result = jsonInt(channel['RESULT']);
  if (result == null) {
    throw const SoopFailure('the channel block carries no RESULT');
  }
  if (result != soopResultLive) {
    return SoopChannel(
      roomId: askedRoomId,
      resultCode: result,
      isLiving: false,
      banned: result == soopResultBanned,
      // 0 and -2 are the site's own answers; anything else is its session or shape problem and is thrown.
      viewers: result == soopResultNoLive ? 0 : null,
    );
  }
  final broadcastId = '${channel['BNO'] ?? ''}'.trim();
  final ownerId = soopRoomId('${channel['BJID'] ?? askedRoomId}');
  if (ownerId != askedRoomId) {
    throw SoopFailure('the channel answer is about $ownerId while asking about $askedRoomId');
  }
  final tags = channel['CATEGORY_TAGS'];
  final viewers = soopViewers(channel);
  String chatUrl;
  String chatNo;
  try {
    chatUrl = soopChatUrl(channel, ownerId);
    chatNo = '${channel['CHATNO'] ?? ''}'.trim();
  } on SoopFailure {
    // The chat socket is a bonus on a channel we can describe: a missing endpoint must not hide the room.
    chatUrl = '';
    chatNo = '';
  }
  return SoopChannel(
    roomId: ownerId,
    resultCode: result,
    // `VIEWPRESET` present is the site's own word for "this is streaming now".
    isLiving: channel['VIEWPRESET'] != null,
    banned: false,
    broadcastId: broadcastId,
    title: soopDisplay(channel['TITLE']),
    nick: soopDisplay(channel['BJNICK']),
    area: tags is List && tags.isNotEmpty ? soopDisplay(tags.first) : '',
    viewers: viewers,
    // The site's own thumbnail address, with the cache-buster its page sends so a reload shows the new picture.
    cover: soopImage(
      'https://liveimg.$soopChatDomain/m/$broadcastId?_t=${(capturedAt ?? DateTime.now()).millisecondsSinceEpoch}',
    ),
    avatar: soopAvatarUrl(ownerId),
    chatUrl: chatUrl,
    chatNo: chatNo,
    streamHost: '${channel['RMD'] ?? ''}'.trim(),
    cdn: '${channel['CDN'] ?? ''}'.trim(),
    qualities: soopQualities(channel['VIEWPRESET']),
  );
}

/// One row of a category list or a search hit.
SoopChannel? soopListingRow(Object? raw, {required String areaName}) {
  final row = jsonMap(raw);
  if (row == null) {
    throw const SoopFailure('a listing row is not an object');
  }
  final id = soopRoomId('${row['user_id'] ?? ''}');
  return SoopChannel(
    roomId: id,
    resultCode: soopResultLive,
    // A grid row is an on-air listing by construction; only the channel answer can contradict that.
    isLiving: true,
    banned: false,
    title: soopDisplay(row['broad_title'] ?? row['TITLE']),
    nick: soopDisplay(row['user_nick']),
    area: soopDisplay(row['broad_cate_name'] ?? row['category_name'] ?? row['standard_broad_cate_name'] ?? areaName),
    viewers: soopViewers(row),
    cover: soopImage(row['thumbnail'] ?? row['broad_img'] ?? row['broad_thumb']),
    avatar: soopImage(row['user_profile_img']).isEmpty ? soopAvatarUrl(id) : soopImage(row['user_profile_img']),
  );
}

/// The SOOP client.
final class SoopApi {
  SoopApi({NetworkClient? client, Clock? clock, String? cookie})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock,
      _cookie = (cookie ?? '').trim();

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;

  /// An operator-supplied session. Soop answers some channels only to a logged-in cookie, and this path never
  /// logs in by itself - what it does with a cookie it was given is recorded in the package README.
  final String _cookie;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Map<String, String> get _headers => soopHeaders(cookie: _cookie);

  /// The category table, paged until the site stops filling a page.
  Future<List<SoopCategory>> categories() async {
    final found = <String, SoopCategory>{};
    for (var page = 1; page <= 10; page++) {
      final data = await _json('$soopSearchOrigin/api.php', <String, String>{
        'm': 'categoryList',
        'szKeyword': '',
        'szOrder': 'view_cnt',
        'nPageNo': '$page',
        'nListCnt': '$soopCategoryPageSize',
        'nOffset': '0',
        'szPlatform': 'pc',
      });
      final rows = jsonMap(data['data'])?['list'];
      if (rows is! List) {
        throw const SoopFailure('the category answer carries no list');
      }
      for (final raw in rows) {
        final row = jsonMap(raw);
        final id = '${row?['category_no'] ?? ''}'.trim();
        final name = soopDisplay(row?['category_name']);
        if (id.isEmpty || name.isEmpty || !RegExp(r'^[0-9]{1,10}$').hasMatch(id)) {
          continue;
        }
        found.putIfAbsent(id, () => SoopCategory(id: id, name: name, image: soopImage(row?['cate_img'])));
      }
      if (rows.length < soopCategoryPageSize) {
        break;
      }
    }
    return found.values.toList(growable: false);
  }

  /// One category's live list.
  Future<List<SoopChannel>> directory({
    required String categoryNo,
    String areaName = '',
    int page = 1,
    int pageSize = soopListPageSize,
  }) async {
    if (!RegExp(r'^[0-9]{1,10}$').hasMatch(categoryNo.trim())) {
      throw SoopFailure('not a soop category id: "$categoryNo"');
    }
    if (page < 1 || page > 10000) {
      throw const SoopFailure('category pages are 1..10000');
    }
    final data = await _json('$soopSearchOrigin/api.php', <String, String>{
      'm': 'categoryContentsList',
      'szType': 'live',
      'nPageNo': '$page',
      'nListCnt': '${pageSize.clamp(1, soopListPageSizeLimit)}',
      'szPlatform': 'pc',
      'szOrder': 'view_cnt_desc',
      'szCateNo': categoryNo.trim(),
    });
    return _rows(jsonMap(data['data'])?['list'], areaName: areaName);
  }

  /// The homepage recommendation block.
  Future<List<SoopChannel>> home({int page = 1}) async {
    if (page < 1 || page > 10000) {
      throw const SoopFailure('pages are 1..10000');
    }
    final data = await _json('$soopLiveOrigin/api/main_broad_list_api.php', <String, String>{
      'selectType': 'action',
      'selectValue': 'all',
      'orderType': 'view_cnt',
      'pageNo': '$page',
      'lang': 'ko_KR',
    });
    return _rows(data['broad'], areaName: '');
  }

  /// The streamer search.
  Future<List<SoopChannel>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final term = keyword.trim();
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const SoopFailure('a search term must be 1-100 printable characters');
    }
    if (page < 1 || page > 10000) {
      throw const SoopFailure('search pages are 1..10000');
    }
    final data = await _json('$soopSearchOrigin/api.php', <String, String>{
      'l': 'DF',
      'm': 'liveSearch',
      'c': 'UTF-8',
      'w': 'webk',
      'isMobile': '0',
      'onlyParent': '1',
      'szType': 'json',
      'szOrder': 'score',
      'szKeyword': term,
      'nPageNo': '$page',
      'nListCnt': '${pageSize.clamp(1, 50)}',
      'tab': 'live',
      'location': 'total_search',
      'isHashSearch': '0',
      'v': '2.0',
    });
    return _rows(data['REAL_BROAD'], areaName: '');
  }

  /// The channel: state, audience, tiers and the material the play signature needs.
  ///
  /// A RESULT outside `1`/`0`/`-2` is thrown rather than turned into an offline room: those codes are a login or
  /// a shape problem, and reading them as "ended" is what makes a follow list stop watching a live channel.
  Future<SoopChannel> channel(String input) async {
    final roomId = soopRoomId(input);
    final data = await _post(
      '$soopLiveOrigin/afreeca/player_live_api.php',
      <String, String>{
        'bid': roomId,
        'bno': '',
        'type': 'live',
        'pwd': '',
        'player_type': 'html5',
        'stream_type': 'common',
        'quality': 'HD',
        'mode': 'landing',
        'from_api': '0',
        'is_revive': 'false',
      },
      <String, String>{'bjid': roomId},
    );
    final channel = soopChannel(data, askedRoomId: roomId, capturedAt: _clock());
    final result = channel.resultCode;
    if (result != soopResultLive && result != soopResultNoLive && result != soopResultBanned) {
      throw SoopFailure('the channel endpoint returned code $result', code: result);
    }
    return channel;
  }

  /// The address for one tier of one broadcast: the assignment answer plus the `aid` the site signs it with.
  ///
  /// Both are needed and neither is cacheable beyond the broadcast, which is why a refresh is a re-sign rather
  /// than a reuse of the url.
  Future<Uri> streamUrl({required SoopChannel channel, required SoopQuality quality}) async {
    if (channel.broadcastId.isEmpty || channel.streamHost.isEmpty) {
      throw const SoopFailure('the channel carries no broadcast number or media host to sign for');
    }
    final assign = await _get(soopAssignUri(channel.streamHost).toString(), <String, String>{
      'return_type': soopReturnType(channel.cdn),
      'broad_key': soopBroadKey(channel.broadcastId, quality.name),
    });
    final viewUrl = soopImage(assign['view_url']);
    final aid = await _aid(channel: channel, quality: quality);
    if (viewUrl.isEmpty || aid.isEmpty) {
      throw SoopFailure('the assignment or signature step returned nothing usable');
    }
    final uri = Uri.tryParse(viewUrl);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.userInfo.isNotEmpty) {
      throw SoopFailure('the assignment named an address this path will not open: "$viewUrl"');
    }
    return uri.replace(query: '${uri.query}${uri.query.isEmpty ? '' : '&'}aid=$aid');
  }

  Future<String> _aid({required SoopChannel channel, required SoopQuality quality}) async {
    final data = await _post(
      '$soopLiveOrigin/afreeca/player_live_api.php',
      <String, String>{
        'bid': channel.roomId,
        'bno': channel.broadcastId,
        'type': 'aid',
        'pwd': '',
        'player_type': 'html5',
        'stream_type': 'common',
        'quality': quality.name,
        'mode': 'landing',
        'from_api': '0',
        'is_revive': 'false',
      },
      <String, String>{'bjid': channel.roomId},
    );
    return '${jsonMap(data['CHANNEL'])?['AID'] ?? ''}'.trim();
  }

  List<SoopChannel> _rows(Object? rows, {required String areaName}) {
    if (rows is! List || rows.length > soopListPageSizeLimit * 10) {
      throw const SoopFailure('the list is missing or unreasonably long');
    }
    final seen = <String>{};
    return <SoopChannel>[
      for (final raw in rows)
        if (soopListingRow(raw, areaName: areaName) case final SoopChannel channel when seen.add(channel.roomId))
          channel,
    ];
  }

  Future<Map<String, Object?>> _get(String url, Map<String, String> query) async {
    final response = await _client.getText(url, headers: _headers, queryParameters: query);
    return _decode(response, url);
  }

  Future<Map<String, Object?>> _json(String url, Map<String, String> query) => _get(url, query);

  Future<Map<String, Object?>> _post(String url, Map<String, String> form, Map<String, String> query) async {
    final response = await _client.postForm(url, form, headers: _headers, queryParameters: query);
    return _decode(response, url);
  }

  Map<String, Object?> _decode(TextResponse response, String url) {
    if (response.statusCode != 200) {
      throw SoopFailure(
        '${Uri.parse(url).host} answered ${response.statusCode}',
        code: response.statusCode,
        missing: response.statusCode == 404,
      );
    }
    Object? decoded;
    try {
      // The site double-encodes some answers: a body that is itself a json string is decoded once more.
      final first = jsonDecode(response.body);
      decoded = first is String ? jsonDecode(first) : first;
    } on FormatException catch (error) {
      throw SoopFailure('${Uri.parse(url).host} answered something that is not json', cause: error);
    }
    final map = jsonMap(decoded);
    if (map == null) {
      throw SoopFailure('${Uri.parse(url).host} answered a non-object body');
    }
    return map;
  }
}

/// One category row.
final class SoopCategory {
  const SoopCategory({required this.id, required this.name, this.image});

  final String id;
  final String name;
  final String? image;

  ContentCategory toContentCategory() => ContentCategory(id: id, name: name, icon: image);
}
