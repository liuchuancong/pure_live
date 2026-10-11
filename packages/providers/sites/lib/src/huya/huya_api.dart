// Module: lib/src/huya/huya_api.dart
// Purpose: What this package asks huya, what it calls itself, and how a lease is signed - the request side only.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. Provenance: the endpoint set, the anti-code recipe and the `rotl64` naming
// follow the v1-maintained huya line (origin/master lib/shared/platforms/huya/huya_site.dart), itself synced from
// dart_simple_live. This is a from-scratch implementation against the capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md): no upstream commit enters this repository through this file.
//
// One file because this is one site's request side, and a site is two files (docs/architecture/package-architecture.md
// §2): the urls, the ids the source uses for itself, the anonymous viewer identity, the AntiCode rebuild, and the
// readers for what those requests return - and huya_site.dart, which only turns them into the platform's
// capability interfaces. There is no per-site model file: 30+ 站点 each with their own model set would be 30+
// copies of the same room/line/ticket shape, and the shared shapes already exist in pure_live_platform
// (ContentSummary / ContentDetail / MediaTicket / StreamOption / LiveRoomStatus). What sits below the readers is
// only the wire shape an endpoint has shipped three different ways, kept next to the endpoint that ships it.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

/// `www.huya.com/cache.php` - the live list page (recommend feed and per-category rooms).
const String huyaListUrl = 'https://www.huya.com/cache.php';

/// `mp.huya.com/cache.php` - profileRoom: the one endpoint that describes a room fully, including its CDN list.
const String huyaProfileRoomUrl = 'https://mp.huya.com/cache.php';

/// `search.cdn.huya.com/` - the search endpoint. Rows are capped at 50 and paging runs through `start`.
const String huyaSearchUrl = 'https://search.cdn.huya.com/';

/// `live.cdn.huya.com/liveconfig/game/bussLive` - one top group's game table.
const String huyaGameConfigUrl = 'https://live.cdn.huya.com/liveconfig/game/bussLive';

/// The four top category groups, with the ids the web config has always used.
const List<(String bussType, String groupName)> huyaTopGroups = <(String, String)>[
  ('1', '网游'),
  ('2', '单机'),
  ('8', '娱乐'),
  ('3', '手游'),
];

/// A desktop Chrome UA: the web endpoints answer to it without a login.
const String huyaUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36';

/// The headers the web endpoints expect from a browser-shaped client.
const Map<String, String> huyaWebHeaders = <String, String>{
  'user-agent': huyaUserAgent,
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// The OSS thumbnail suffix the web list asks the CDN for; the raw screenshot is several times larger.
const String huyaCoverThumbQuery = '?x-oss-process=style/w338_h190&';

/// The source id every huya row carries. A source id is also the ContentRef sourceId (plugin-manifest.md §2), so
/// it outlives any refactor of this package: changing it orphans every stored favourite, history row and ticket.
const String huyaSourceId = 'huya.live';

/// The ticket metadata key naming the CDN entry a ticket was opened from, 1-based as a surface shows it.
const String huyaLineKey = 'huya.line';

/// The ticket metadata key holding how many CDN entries the room offered at resolve time.
const String huyaLineCountKey = 'huya.lineCount';

/// The ticket metadata key recording a quality the viewer asked for and the anonymous path cannot give.
const String huyaRequestedQualityKey = 'huya.requestedQuality';

/// profileRoom refused to describe a room.
///
/// A bare StateError saying "status 404" is undiagnosable a week later: a closed room, a deleted room and a
/// risk-control refusal all answer there, and the message the endpoint sent is the only thing that tells them
/// apart (docs/contracts/provider-contract.md).
final class HuyaProfileRequestFailure implements Exception {
  const HuyaProfileRequestFailure(this.roomId, {required this.status, this.message});

  /// The room that was asked about.
  final String roomId;

  /// The endpoint's own status field, as text - `null` in the answer is `'none'`, not a missing field.
  final String status;

  /// The site's message, kept verbatim because that is what distinguishes the three refusals above.
  final String? message;

  @override
  String toString() =>
      'HuyaProfileRequestFailure($roomId answered status $status'
      '${message == null ? '' : ': $message'})';
}

/// Huya's web player names this operation `rotl64`: only the low 32-bit lane is
/// rotated while the upper lane of the 64-bit viewer uid is preserved.
/// Rotating only the low lane and returning it would truncate real anonymous
/// uids (> 2^32) and the CDN answers with 403.
int rotateViewerUid32(int value) {
  final low = value & 0xffffffff;
  final high = value - low;
  final rotatedLow = ((low << 8) | (low >> 24)) & 0xffffffff;
  return high | rotatedLow;
}

/// An anonymous viewer uid in the range the web player issues. Random.nextInt
/// only supports ranges up to 2^32, so the 100-billion offset is composed from
/// two supported uniform draws.
int createFallbackViewerUid() {
  final random = Random.secure();
  final offset = random.nextInt(1000000) * 100000 + random.nextInt(100000);
  return 1400000000000 + offset;
}

/// Rebuilds [antiCode] for one open of [stream] as viewer [viewerUid].
///
/// [now] is injectable for deterministic callers; production calls pass
/// nothing and get the current wall clock. Throws [FormatException] when the
/// template is unreadable and [StateError] when the wsTime lease has already
/// lapsed - both mean "do not open this URL", not "open it and see".
///
/// How it works: when the server-issued antiCode carries an `fm` field, that field is a base64 template whose
/// `$0..$3` placeholders take the viewer uid, stream name, a seqid hash and wsTime; md5 of the filled template is
/// the wsSecret the CDN accepts. An antiCode without `fm` is already signed and passes through untouched.
String buildAntiCode(String stream, int viewerUid, String antiCode, {DateTime? now}) {
  final original = Uri(query: antiCode).queryParameters;
  final encodedFm = original['fm']?.trim() ?? '';
  if (encodedFm.isEmpty) {
    return antiCode;
  }

  final ctype = original['ctype']?.trim().isNotEmpty == true ? original['ctype']!.trim() : 'huya_webh5';
  final platformId = original['t']?.trim().isNotEmpty == true ? original['t']!.trim() : '100';
  final isWap = platformId == '103';
  final timestamp = now ?? DateTime.now();
  final currentMillis = timestamp.millisecondsSinceEpoch;
  final currentSeconds = currentMillis ~/ 1000;
  final uid = viewerUid > 0 ? viewerUid : createFallbackViewerUid();

  final wsTimeRaw = original['wsTime']?.trim() ?? '';
  final wsTimeSeconds = int.tryParse(wsTimeRaw, radix: 16);
  if (wsTimeSeconds == null) {
    throw const FormatException('Huya AntiCode has no valid wsTime');
  }
  if (currentSeconds > wsTimeSeconds + const Duration(minutes: 5).inSeconds) {
    throw StateError('Huya AntiCode lease expired');
  }
  final wsTime = wsTimeRaw.toLowerCase();
  final seqId = uid + currentMillis;
  final secretHash = md5.convert(utf8.encode('$seqId|$ctype|$platformId')).toString();

  final convertedUid = rotateViewerUid32(uid);
  final calcUid = isWap ? uid : convertedUid;
  // The official player treats `fm` as a server-owned template and replaces its four placeholders in place.
  // Splitting on `_` and rebuilding a presumed layout would silently sign the wrong string as soon as Huya
  // adds a field; the complete decoded template is preserved instead.
  final secretTemplate = utf8.decode(base64.decode(base64.normalize(encodedFm)));
  final secretStr = fillAntiCodeTemplate(
    secretTemplate,
    calcUid: calcUid,
    stream: stream,
    secretHash: secretHash,
    wsTime: wsTime,
  );
  final wsSecret = md5.convert(utf8.encode(secretStr)).toString();

  final random = Random.secure();
  final ct = ((wsTimeSeconds + random.nextDouble()) * 1000).toInt();
  final uuid = (((ct % 1e10) + random.nextDouble()) * 1e3 % 0xffffffff).toInt().toString();
  final result = <String, String>{...original}
    ..remove('wsSecret')
    ..remove('seqid')
    ..remove('u')
    ..remove('uid')
    ..remove('uuid')
    // `fm` is signing material, not a media query field: the official web player consumes it locally and
    // omits it from the emitted CDN URL.
    ..remove('fm')
    ..addAll(<String, String>{
      'wsSecret': wsSecret,
      'wsTime': wsTime,
      'seqid': seqId.toString(),
      'ctype': ctype,
      'ver': '1',
      'fs': original['fs'] ?? 'bgct',
      't': platformId,
    });
  if (isWap) {
    result.addAll(<String, String>{'uid': uid.toString(), 'uuid': uuid});
  } else {
    result['u'] = convertedUid.toString();
  }

  return Uri(queryParameters: result).query;
}

/// Fills the four `fm` placeholders in one left-to-right pass.
///
/// Sequential `replaceFirst`s would let an earlier substitution feed a later one: a room whose name contains
/// `$2` (rooms do have such names) would have its own text replaced by the hash, and the signature would be
/// computed over a string the server never templated. Each placeholder is also required to exist, because a
/// template missing one is a shape change, not a shorter lease.
String fillAntiCodeTemplate(
  String template, {
  required int calcUid,
  required String stream,
  required String secretHash,
  required String wsTime,
}) {
  final replacements = <String, String>{r'$0': calcUid.toString(), r'$1': stream, r'$2': secretHash, r'$3': wsTime};
  final missing = <String>[...replacements.keys].where((placeholder) => !template.contains(placeholder)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('Huya AntiCode fm template is incomplete: ${missing.join(', ')}');
  }
  // One left-to-right pass. Each placeholder is filled at its first occurrence - which is what the site's own
  // client does with a string pattern in JavaScript's replace - and the text written in is never re-scanned,
  // so a room name that itself reads `$2` cannot be signed over.
  final buffer = StringBuffer();
  final filled = <String>{};
  for (var index = 0; index < template.length; index++) {
    if (template[index] != r'$' || index + 1 >= template.length) {
      buffer.write(template[index]);
      continue;
    }
    final placeholder = template.substring(index, index + 2);
    final replacement = replacements[placeholder];
    if (replacement == null || filled.contains(placeholder)) {
      buffer.write(template[index]);
      continue;
    }
    buffer.write(replacement);
    filled.add(placeholder);
    index++;
  }
  return buffer.toString();
}

/// One `baseSteamInfoList` row: the same content on a different delivery path.
///
/// The field name is the endpoint's own, typo included. An entry carries both an flv and an hls url plus a
/// different anti-code per container, so picking a line means picking one of these - the pair has to stay
/// together rather than being flattened into two url lists that can drift apart.
final class HuyaStreamEntry {
  const HuyaStreamEntry({
    required this.streamName,
    this.hlsUrl,
    this.flvUrl,
    this.hlsSuffix,
    this.flvSuffix,
    this.hlsAntiCode = '',
    this.flvAntiCode = '',
  });

  factory HuyaStreamEntry.fromJson(Map<String, Object?> json) => HuyaStreamEntry(
    streamName: '${json['sStreamName'] ?? ''}',
    hlsUrl: jsonString(json['sHlsUrl']),
    flvUrl: jsonString(json['sFlvUrl']),
    hlsSuffix: jsonString(json['sHlsUrlSuffix']),
    flvSuffix: jsonString(json['sFlvUrlSuffix']),
    hlsAntiCode: '${json['sHlsAntiCode'] ?? ''}',
    flvAntiCode: '${json['sFlvAntiCode'] ?? ''}',
  );

  /// The stream name inside the path; the manifest file is `<streamName>.<suffix>`.
  final String streamName;

  /// The HLS base url. Null when the entry ships only an flv one, which happens on the less common CDNs -
  /// preferring it is why this package stopped rewriting `flv` into `hls` textually.
  final String? hlsUrl;
  final String? flvUrl;

  /// The container suffix the source itself names (`m3u8` / `flv`). Only trusted for the url it came with.
  final String? hlsSuffix;
  final String? flvSuffix;

  /// The lease material, per container. An hls answer signs with [hlsAntiCode]; the flv fallback with
  /// [flvAntiCode] - they are not interchangeable, and the anti-code carries the container in its own fields.
  final String hlsAntiCode;
  final String flvAntiCode;

  /// Whether this row can produce a stream at all: a name and some base url.
  bool get isUsable => streamName.isNotEmpty && (hlsUrl != null || flvUrl != null);
}

/// A room as `profileRoom` described it - the one endpoint that answers four questions at once.
final class HuyaRoomProfile {
  const HuyaRoomProfile({
    required this.roomId,
    required this.liveStatusCode,
    this.roomName = '',
    this.introduction = '',
    this.anchorName = '',
    this.screenshot,
    this.viewers,
    this.entries = const <HuyaStreamEntry>[],
  });

  /// Reads one profileRoom payload. [raw] is the `data` object; a room that does not exist answers without one,
  /// and the caller decides what that means for its capability.
  factory HuyaRoomProfile.fromJson(String roomId, Map<String, Object?> raw) {
    final liveData = jsonMap(raw['liveData']) ?? const <String, Object?>{};
    final stream = jsonMap(raw['stream']) ?? const <String, Object?>{};
    // The CDN list has shipped at both the top level and inside `stream`; the top-level one is the fallback,
    // not the other way round, because a stream block that exists but lists nothing means "no CDN right now".
    final listed = jsonList(stream['baseSteamInfoList']);
    return HuyaRoomProfile(
      roomId: roomId,
      liveStatusCode: jsonInt(liveData['liveStatus']) ?? jsonInt(raw['liveStatus']) ?? -1,
      roomName: '${liveData['sRoomName'] ?? raw['sRoomName'] ?? ''}',
      introduction: '${liveData['introduction'] ?? raw['introduction'] ?? ''}',
      anchorName: '${liveData['nick'] ?? raw['nick'] ?? ''}',
      screenshot: jsonString(liveData['screenshot'] ?? raw['screenshot']),
      viewers: jsonInt(liveData['userCount'] ?? raw['userCount']),
      entries: <HuyaStreamEntry>[
        for (final entry in listed.isEmpty ? jsonList(raw['baseSteamInfoList']) : listed)
          if (entry is Map) HuyaStreamEntry.fromJson(Map<String, Object?>.from(entry)),
      ],
    );
  }

  final String roomId;

  /// The raw flag the endpoint sends. `1` is on air; anything else - including a response that omitted it,
  /// which reads as -1 - is "not live or unknown", and the two are told apart by [isLiveKnown].
  final int liveStatusCode;

  final String roomName;
  final String introduction;
  final String anchorName;
  final String? screenshot;

  /// Viewer count as the platform reported it; null means it did not say, which is not zero.
  final int? viewers;

  /// The CDN entries, in the source's own priority order. Empty means the room is not streaming.
  final List<HuyaStreamEntry> entries;

  bool get isLive => liveStatusCode == 1;

  bool get isLiveKnown => liveStatusCode >= 0;

  bool get hasStream => entries.any((entry) => entry.isUsable);
}

/// A huya room as one of the list endpoints reported it.
///
/// The two endpoints describe the same room with different field names (`profileRoom`/`room_id`,
/// `screenshot`/`game_screenshot`, `nick`/`game_nick`), so both readings land in one row type and only one place
/// turns it into a [ContentSummary]. Two conversions drift: one gets fixed after a field rename and the other
/// keeps showing blank tiles.
final class HuyaListRow {
  const HuyaListRow({
    required this.roomId,
    this.title = '',
    this.fallbackTitle = '',
    this.anchorName = '',
    this.areaName = '',
    this.cover,
    this.viewers,
  });

  /// From a `getLiveListByPage` row.
  factory HuyaListRow.fromList(Map<String, Object?> row) => HuyaListRow(
    roomId: '${row['profileRoom'] ?? ''}',
    title: '${row['introduction'] ?? ''}',
    fallbackTitle: '${row['roomName'] ?? ''}',
    anchorName: '${row['nick'] ?? ''}',
    areaName: '${row['gameFullName'] ?? ''}',
    cover: _thumb(row['screenshot']),
    viewers: jsonInt(row['totalCount']),
  );

  /// From a search `docs` row.
  factory HuyaListRow.fromSearch(Map<String, Object?> row) => HuyaListRow(
    roomId: '${row['room_id'] ?? ''}',
    title: '${row['game_introduction'] ?? ''}',
    fallbackTitle: '${row['game_roomName'] ?? ''}',
    anchorName: '${row['game_nick'] ?? ''}',
    areaName: '${row['gameName'] ?? ''}',
    cover: _thumb(row['game_screenshot'] ?? row['game_imgUrl']),
    viewers: jsonInt(row['game_onlineCount']),
  );

  final String roomId;

  /// The line the source shows first; [fallbackTitle] is what it shows when that is empty.
  final String title;
  final String fallbackTitle;
  final String anchorName;
  final String areaName;
  final String? cover;

  /// Null means the endpoint did not say, which is not the same as zero viewers.
  final int? viewers;

  /// The row as the platform's summary, in the source's own vocabulary.
  ContentSummary toSummary() => ContentSummary(
    ref: ContentRef(sourceId: huyaSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: title.trim().isNotEmpty ? title : fallbackTitle,
    subtitle: <String>[if (anchorName.isNotEmpty) anchorName, if (areaName.isNotEmpty) areaName].join(' · '),
    cover: cover,
    metadata: ContentMetadata(popularity: viewers),
  );

  /// The OSS thumbnail parameter, added only where the url does not already carry a query.
  static String? _thumb(Object? value) {
    final raw = '${value ?? ''}';
    if (raw.isEmpty) {
      return null;
    }
    return raw.contains('?') ? raw : '$raw$huyaCoverThumbQuery';
  }
}

/// The room as one object, from the profileRoom document that already answers everything else about it.
///
/// Huya states no paywall or schedule flag on the anonymous path, so those stay false rather than being inferred
/// from "the stream was empty" - an empty CDN list is an off-air or between-segments moment, not a gate.
/// `streamId` carries the per-broadcast stream name because it is exactly that: valid for this broadcast only,
/// never usable as the room's identity.
LiveRoom huyaLiveRoom(HuyaRoomProfile profile) {
  final title = profile.roomName.trim();
  final anchor = profile.anchorName.trim();
  return LiveRoom(
    ref: ContentRef(sourceId: huyaSourceId, contentId: profile.roomId, kind: ContentKind.liveRoom),
    state: switch (profile.liveStatusCode) {
      1 => LiveRoomState.live,
      0 => LiveRoomState.ended,
      _ => LiveRoomState.unknown,
    },
    title: title.isNotEmpty ? title : anchor,
    anchorName: anchor.isEmpty ? null : anchor,
    cover: profile.screenshot,
    viewers: profile.viewers,
    introduction: profile.introduction.trim().isEmpty ? null : profile.introduction.trim(),
    streamId: profile.entries.isEmpty ? null : profile.entries.first.streamName,
    extra: <String, Object?>{if (profile.entries.length > 1) 'cdnLines': profile.entries.length},
  );
}
