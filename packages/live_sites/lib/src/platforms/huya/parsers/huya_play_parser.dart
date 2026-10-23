import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The milliseconds a signature uses for `seqid`: never behind the wall
/// clock and strictly increasing, so two opens in the same millisecond still
/// get different `seqid` and `wsSecret`.
final class HuyaSignClock {
  int _last = 0;

  /// The next signing millisecond at the wall time [now].
  int next(DateTime now) {
    final wall = now.millisecondsSinceEpoch;
    return _last = wall > _last ? wall : _last + 1;
  }
}

/// The window a WUP play token is worth: renew at its `refreshAt`, stop
/// accepting it at its `invalidAt`.
typedef HuyaTokenWindow = ({DateTime refreshAt, DateTime invalidAt});

/// One CDN line of a live room before signing: a `multiLine` entry of the
/// FLV or HLS group joined with its `baseSteamInfoList` stream.
final class HuyaLine {
  /// Creates a line.
  const HuyaLine({
    required this.cdnType,
    required this.format,
    required this.base,
    required this.streamName,
    required this.antiCode,
    required this.presenterUid,
  });

  /// Server CDN code (`AL`, `TX`, `HS24`): `multiLine[].cdnType`.
  final String cdnType;

  /// FLV or HLS.
  final LiveStreamFormat format;

  /// CDN base without the stream name; `http://` on a huya.com host already
  /// upgraded to https.
  final String base;

  /// Stream name.
  final String streamName;

  /// The room's AntiCode for this format: `sFlvAntiCode` for FLV,
  /// `sHlsAntiCode` for HLS, never the other one.
  final String antiCode;

  /// The uid that signs this line: `lPresenterUid`, else `profileInfo.uid`,
  /// else `lChannelId`; 0 when none.
  final int presenterUid;

  /// Diagnostics without tokens or stream names.
  @override
  String toString() => 'HuyaLine($cdnType ${format.name} ${Uri.tryParse(base)?.host ?? 'unknown'})';
}

/// The web play path of a huya live room: qualities and lines built from a
/// `profileRoom` answer's embedded `stream`, the `signAntiCode` MD5 template
/// signer, and the media URL / headers / lease every line is issued with.
///
/// Builds play lines from `profileRoom`'s `multiLine`, signs their `AntiCode`
/// on the web path, and reads a replay's VOD recording (`liveData.hls`). The
/// native `getCdnTokenInfoEx` WUP play token (see [cdnTokenRequest] /
/// [cdnTokenResponse] / [tokenWindow]) signs FLV lines as the caller prefers.
abstract final class HuyaPlayParser {
  /// Rank of the source quality (bit rate 0), above every transcode.
  static const int sourceRank = 1 << 30;

  /// The `definition` of a replay's source recording.
  static const String replaySourceDefinition = 'yuanhua';

  /// Names of the replay definitions seen in `getMomentContent`, for the one
  /// quality `profileRoom` names when that list is not read.
  static const Map<String, String> replayDefinitionNames = {
    replaySourceDefinition: '原画',
    '1300': '720P',
    '350': '360P',
  };

  /// A recording playlist: an http(s) `.m3u8` URL, `http://` on huya.com
  /// upgraded to https (the VOD CDN serves both); null for anything else, so a
  /// live quality's bit rate is never taken for a recording.
  static String? replayUrl(Object? value) {
    if (value is! String) return null;
    final uri = jsonUrl(value);
    if (uri == null || !uri.path.toLowerCase().endsWith('.m3u8')) return null;
    return secureBase(value.trim());
  }

  /// The one quality of the recording at [url], named by its `definition`
  /// ([replayDefinitionNames]; `默认` when unknown). Its id is the https
  /// playlist itself — a replay's `qualityId` is the line the playback provider
  /// echoes back, and a VOD playlist does not expire or need signing.
  static LivePlayQuality replayQuality(String url) {
    final definition = _parseMap(Uri.tryParse(url)?.query ?? '')['definition'] ?? '';
    final quality = replayDefinitionNames[definition] ?? '默认';
    return LivePlayQuality.of(
      label: quality,
      qualityId: url,
      platformOrder: definition == replaySourceDefinition ? sourceRank : 0,
      codec: LiveStreamCodec.avc,
    );
  }

  /// The `fm` key the web player signs (3.x's test before signing; an empty
  /// `fm` then signs as the query unchanged).
  static final RegExp _templateKey = RegExp('(^|&)fm=');

  /// Whether [antiCode] carries an `fm` key at all.
  static bool hasTemplate(String antiCode) => _templateKey.hasMatch(antiCode);

  /// Qualities of a live room's `profileRoom` [data]: the rate list is
  /// `liveData.bitRateInfo` (a JSON string or a list), else
  /// `stream.flv.rateArray`. The id is the bit rate (0 is the source); blank
  /// names and negative rates are dropped, the first of a rate wins, the
  /// source first then by rate. Without rates, one `原画` at 0 — never an
  /// invented transcode.
  static List<LivePlayQuality> qualities(Map<String, dynamic> data) {
    Object? info = jsonObject(data['liveData'])?['bitRateInfo'];
    if (info is String) {
      try {
        info = info.trim().isEmpty ? null : jsonDecode(info);
      } on FormatException {
        info = null;
      }
    }
    if (info is! List) {
      info = jsonObject(jsonObject(jsonObject(data['stream'])?['flv']))?['rateArray'];
    }
    final rates = info is List ? info : const <Object?>[];
    final seen = <int>{};
    final named = <({String name, int rate})>[];
    for (final raw in rates) {
      final item = jsonObject(raw);
      final name = jsonString(item?['sDisplayName']);
      final rate = jsonInt(item?['iBitRate']);
      if (name == null || name.isEmpty || rate == null || rate < 0 || !seen.add(rate)) continue;
      named.add((name: name, rate: rate));
    }
    if (named.isEmpty) named.add((name: '原画', rate: 0));
    final sorted = [...named]..sort((a, b) => _rank(b.rate).compareTo(_rank(a.rate)));
    return [
      for (final (index, entry) in sorted.indexed)
        LivePlayQuality.of(
          label: entry.name,
          qualityId: '${entry.rate}',
          platformOrder: sorted.length - index,
          codec: LiveStreamCodec.avc,
        ),
    ];
  }

  static int _rank(int rate) => rate == 0 ? sourceRank : rate;

  /// Lines: `stream.flv.multiLine` then `stream.hls.multiLine`, server order,
  /// entries with a non-empty `url` whose `cdnType` matches a base stream's
  /// `sCdnType`. Base streams `multiLine` does not list are left out.
  static List<HuyaLine> lines(Map<String, dynamic> stream, List<Map<String, dynamic>> bases, int? profileUid) {
    final result = <HuyaLine>[];
    final seen = <String>{};
    for (final (format, key, urlKey, codeKey) in const [
      (LiveStreamFormat.flv, 'flv', 'sFlvUrl', 'sFlvAntiCode'),
      (LiveStreamFormat.hls, 'hls', 'sHlsUrl', 'sHlsAntiCode'),
    ]) {
      for (final raw in jsonList(jsonObject(stream[key])?['multiLine'])) {
        final item = jsonObject(raw);
        final cdn = jsonString(item?['cdnType']);
        if (item == null || cdn == null || jsonString(item['url']) == null) continue;
        final base = bases.where((base) => jsonString(base['sCdnType']) == cdn).firstOrNull;
        final url = jsonString(base?[urlKey]);
        final name = jsonString(base?['sStreamName']);
        if (base == null || url == null || name == null || !seen.add('${format.name}:$cdn')) continue;
        result.add(
          HuyaLine(
            cdnType: cdn,
            format: format,
            base: secureBase(url),
            streamName: name,
            antiCode: jsonString(base[codeKey]) ?? '',
            presenterUid: jsonInt(base['lPresenterUid']) ?? profileUid ?? jsonInt(base['lChannelId']) ?? 0,
          ),
        );
      }
    }
    return result;
  }

  /// An `http://` base on a huya.com host becomes https; other hosts stay.
  static String secureBase(String base) {
    final uri = Uri.tryParse(base);
    if (uri == null || uri.scheme != 'http' || !_isHuyaHost(uri.host)) return base;
    return uri.replace(scheme: 'https').toString();
  }

  /// Signs [antiCode] for [streamName] as [uid] (the `AntiCode` MD5 template;
  /// NOT the WUP `wskey`). A query without an `fm` value is returned
  /// unchanged. Parameters the signer does not own keep their spelling and
  /// position.
  ///
  /// - `seqid = uid + clock.next(now)`; `hash = md5("seqid|ctype|t")`;
  ///   `ctype` defaults to `huya_webh5`, `t` to `100`; `t=103` is WAP.
  /// - `wsSecret = md5(template)` with the first `$0` replaced by the rotated
  ///   uid (the uid itself for WAP), `$1` by the stream, `$2` by the hash and
  ///   `$3` by `wsTime` (lower case). The whole server template is used; no
  ///   layout is assumed.
  /// - Output: `wsSecret seqid u uid uuid fm` removed, then `wsSecret`,
  ///   `wsTime`, `seqid`, `ctype`, `ver=1`, `fs` (default `bgct`), `t`, and
  ///   `u` (WAP: `uid` and a random `uuid`), an existing key replaced in
  ///   place, a missing one appended.
  ///
  /// Throws a [HuyaFailure]: [HuyaFailureKind.apiChanged] without a
  /// hexadecimal `wsTime`, with an `fm` that does not decode or a template
  /// missing a placeholder; [HuyaFailureKind.streamUnavailable] past `wsTime
  /// + 300 s` (the credential is never extended locally).
  static String signAntiCode(
    String antiCode, {
    required String streamName,
    required int uid,
    required HuyaSignClock clock,
    required DateTime now,
    Random? random,
  }) {
    final params = _parse(antiCode);
    String? value(String key) {
      for (final param in params) {
        if (param.key != key) continue;
        try {
          if (RegExp('%(?![0-9A-Fa-f]{2})').hasMatch(param.value)) throw const FormatException();
          return Uri.decodeComponent(param.value).trim();
        } on FormatException {
          throw HuyaFailure(HuyaFailureKind.apiChanged, '$key is not percent-encoded UTF-8');
        }
      }
      return null;
    }

    String orDefault(String? value, String fallback) => value == null || value.isEmpty ? fallback : value;

    final fm = value('fm') ?? '';
    if (fm.isEmpty) return antiCode;
    if (uid <= 0) throw const HuyaFailure(HuyaFailureKind.apiChanged, 'no signing uid');
    final ctype = orDefault(value('ctype'), 'huya_webh5');
    final platform = orDefault(value('t'), '100');
    final wap = platform == '103';
    final wsTime = (value('wsTime') ?? '').toLowerCase();
    final wsSeconds = RegExp(r'^[0-9a-f]+$').hasMatch(wsTime) ? int.tryParse(wsTime, radix: 16) : null;
    if (wsSeconds == null) throw const HuyaFailure(HuyaFailureKind.apiChanged, 'no hexadecimal wsTime');
    final String template;
    try {
      template = utf8.decode(base64.decode(base64.normalize(fm)));
    } on FormatException {
      throw const HuyaFailure(HuyaFailureKind.apiChanged, 'fm is not base64 UTF-8');
    }
    if (!const [r'$0', r'$1', r'$2', r'$3'].every(template.contains)) {
      throw const HuyaFailure(HuyaFailureKind.apiChanged, r'fm template lacks $0-$3');
    }

    final millis = clock.next(now);
    if (millis ~/ 1000 > wsSeconds + 300) {
      throw const HuyaFailure(HuyaFailureKind.streamUnavailable, 'wsTime + 300 s has passed');
    }
    final seqId = uid + millis;
    final hash = md5.convert(utf8.encode('$seqId|$ctype|$platform')).toString();
    final rotated = rotateUid(uid);
    final secret = template
        .replaceFirst(r'$0', '${wap ? uid : rotated}')
        .replaceFirst(r'$1', streamName)
        .replaceFirst(r'$2', hash)
        .replaceFirst(r'$3', wsTime);
    final wsSecret = md5.convert(utf8.encode(secret)).toString();

    final output = [
      for (final param in params)
        if (!const {'wsSecret', 'seqid', 'u', 'uid', 'uuid', 'fm'}.contains(param.key))
          (key: param.key, raw: param.raw),
    ];
    void put(String key, String value) {
      final segment = (key: key, raw: '$key=${Uri.encodeQueryComponent(value)}');
      final index = output.indexWhere((param) => param.key == key);
      if (index < 0) {
        output.add(segment);
      } else {
        output[index] = segment;
      }
    }

    put('wsSecret', wsSecret);
    put('wsTime', wsTime);
    put('seqid', '$seqId');
    put('ctype', ctype);
    put('ver', '1');
    put('fs', value('fs') ?? 'bgct');
    put('t', platform);
    if (wap) {
      final rng = random ?? Random();
      final ct = ((wsSeconds + rng.nextDouble()) * 1000).toInt();
      final uuid = (((ct % 1e10) + rng.nextDouble()) * 1e3 % 0xffffffff).toInt();
      put('uid', '$uid');
      put('uuid', '$uuid');
    } else {
      put('u', '$rotated');
    }
    return output.map((param) => param.raw).join('&');
  }

  /// `u = rotl(uid)`: the low 32 bits rotate left by 8, the high 32 bits stay
  /// (anonymous uids are above 2^32, so only the low half turns).
  static int rotateUid(int uid) {
    final low = uid & 0xFFFFFFFF;
    return (uid - low) | (((low << 8) | (low >> 24)) & 0xFFFFFFFF);
  }

  /// The inverse of [rotateUid].
  static int unrotateUid(int value) {
    final low = value & 0xFFFFFFFF;
    return (value - low) | (((low >> 8) | (low << 24)) & 0xFFFFFFFF);
  }

  /// The media query for [bitRate]: `codec=264` added when absent
  /// (`codec=265` with [hevc]); `ratio` set to the rate, or removed for the
  /// source (0), never the one captured with the page.
  static String mediaQuery(String antiCode, {required int bitRate, bool hevc = false}) {
    final query = RegExp('(^|&)codec=').hasMatch(antiCode) ? antiCode : '$antiCode&codec=${hevc ? 265 : 264}';
    return replaceQueryParameter(query, 'ratio', bitRate > 0 ? '$bitRate' : null);
  }

  /// [query] with the first [key] set to [value] in place and later ones
  /// removed; appended when absent; removed entirely when [value] is null.
  /// Empty segments are dropped.
  static String replaceQueryParameter(String query, String key, String? value) {
    final output = <String>[];
    var replaced = false;
    for (final segment in query.split('&')) {
      if (segment.isEmpty) continue;
      final separator = segment.indexOf('=');
      if ((separator < 0 ? segment : segment.substring(0, separator)) != key) {
        output.add(segment);
        continue;
      }
      if (!replaced && value != null) output.add('$key=$value');
      replaced = true;
    }
    if (!replaced && value != null) output.add('$key=$value');
    return output.join('&');
  }

  /// `{base}/{streamName}.{flv|m3u8}?{mediaQuery}`. [hevc] asks an FLV line
  /// for HEVC; HLS always asks for H.264.
  static Uri mediaUrl(HuyaLine line, {required String antiCode, required int bitRate, bool hevc = false}) {
    final base = line.base.endsWith('/') ? line.base.substring(0, line.base.length - 1) : line.base;
    final extension = line.format == LiveStreamFormat.hls ? 'm3u8' : 'flv';
    final query = mediaQuery(antiCode, bitRate: bitRate, hevc: hevc && line.format == LiveStreamFormat.flv);
    return Uri.parse('$base/${line.streamName}.$extension?$query');
  }

  /// The video codec a media URL is known to deliver: `codec=264` is AVC.
  /// `codec=265` only asks for HEVC (a room without an HEVC transcode answers
  /// H.264), so it stays null (unknown).
  static LiveStreamCodec? codecOf(Uri url) => switch (_parseMap(url.query)['codec']) {
    '264' => LiveStreamCodec.avc,
    _ => null,
  };

  /// Media request headers for room [roomId], shared by playback and
  /// recording: the HYSDK UA, Origin, the room page as Referer and the login
  /// cookie when there is one.
  static Map<String, String> mediaHeaders(
    String roomId, {
    String userAgent = HuyaEndpoints.hysdkUserAgent,
    String? cookie,
  }) {
    final id = Uri.encodeComponent(roomId.trim());
    return {
      'user-agent': userAgent,
      'origin': HuyaEndpoints.origin,
      'referer': id.isEmpty ? '${HuyaEndpoints.origin}/' : '${HuyaEndpoints.origin}/$id',
      if (cookie != null && cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
    };
  }

  /// A native signed FLV: a huya.com `.flv` with `ctype=huya_pc_exe` and
  /// `t=100`. Its credential only limits new connections.
  static bool isNativeFlv(Uri url) {
    final query = _parseMap(url.query);
    return _isHuyaHost(url.host) &&
        url.path.toLowerCase().endsWith('.flv') &&
        query['ctype'] == 'huya_pc_exe' &&
        query['t'] == '100';
  }

  /// A web FLV (static tokens too) or HLS on huya.com: the CDN closes the
  /// connection about two minutes after the URL was issued.
  static bool hasShortTransportLease(Uri url) {
    final path = url.path.toLowerCase();
    return _isHuyaHost(url.host) && (path.endsWith('.flv') || path.endsWith('.m3u8')) && !isNativeFlv(url);
  }

  /// When a signed URL was issued: `seqid − uid`, the uid being `u` rotated
  /// back (WAP `t=103`: `uid`); null without a plausible value.
  static DateTime? signedIssuedAt(Uri url) {
    final query = _parseMap(url.query);
    final wap = query['t'] == '103';
    final seqId = int.tryParse(query['seqid'] ?? '');
    final encoded = int.tryParse(query[wap ? 'uid' : 'u'] ?? '');
    if (seqId == null || encoded == null) return null;
    final millis = seqId - (wap ? encoded : unrotateUid(encoded));
    if (millis < DateTime.utc(2020).millisecondsSinceEpoch || millis > DateTime.utc(2100).millisecondsSinceEpoch) {
      return null;
    }
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final signedInvalidAt = _wsTime(query['wsTime'])?.add(const Duration(minutes: 5));
    return signedInvalidAt != null && issuedAt.isAfter(signedInvalidAt) ? null : issuedAt;
  }

  /// The lease of a signed media [url]:
  ///
  /// - invalid at `wsTime + 300 s`, at the [token] window's end, or, for a
  ///   short transport lease, at the issued time + 125 s (whichever is
  ///   earliest);
  /// - refreshed 30 s before that, before the [token] window's renew point,
  ///   or at issued + 100 s;
  /// - the issue time is [signedIssuedAt], else [builtAt] (a static token
  ///   without `seqid`).
  ///
  /// Null when nothing bounds the URL.
  static LivePlayLease? lease(Uri url, {DateTime? builtAt, HuyaTokenWindow? token}) {
    final signedInvalidAt = _wsTime(_parseMap(url.query)['wsTime'])?.add(const Duration(minutes: 5));
    final issuedAt = hasShortTransportLease(url) ? signedIssuedAt(url) ?? builtAt?.toUtc() : null;
    final invalidAt = _earliest([signedInvalidAt, token?.invalidAt, issuedAt?.add(const Duration(seconds: 125))]);
    if (invalidAt == null) return null;
    final refreshAt = _earliest([
      signedInvalidAt?.subtract(const Duration(seconds: 30)),
      token?.refreshAt,
      issuedAt?.add(const Duration(seconds: 100)),
    ]);
    if (refreshAt == null) return null;
    return LivePlayLease.of(refreshAt: refreshAt, expiresAt: invalidAt, requiresReconnect: issuedAt != null);
  }

  /// [line] signed with the already-signed [antiCode] at the media [bitRate],
  /// as a [LivePlayLine] for room [roomId] issued at [issuedAt]. The format is
  /// the line's own (declared); the codec is inferred from the URL.
  static LivePlayLine answer(
    HuyaLine line, {
    required String antiCode,
    required int bitRate,
    required String roomId,
    required String cookie,
    required DateTime issuedAt,
    HuyaTokenWindow? token,
    bool hevc = false,
  }) {
    final url = mediaUrl(line, antiCode: antiCode, bitRate: bitRate, hevc: hevc);
    return LivePlayLine.of(
      url: url.toString(),
      format: line.format,
      formatSource: LivePlayFormatSource.declared,
      headers: mediaHeaders(roomId, cookie: cookie),
      codec: codecOf(url),
      lineLabel: line.cdnType.isEmpty ? null : line.cdnType,
      lease: lease(url, builtAt: issuedAt, token: token),
    );
  }

  /// The window of a WUP play token received at [receivedAt] (3.x
  /// `HuyaCdnTokenLease.fromResponse`): valid until `wsTime + 300 s`, or the
  /// earlier bound `iExpireTime` gives (above 10^12 milliseconds, above 10^9
  /// seconds, else seconds after receipt); refreshed 30 s before. An empty
  /// token or one without a hexadecimal `wsTime` is api-changed.
  static HuyaTokenWindow tokenWindow(String token, {required int expireTime, required DateTime receivedAt}) {
    if (token.trim().isEmpty) throw const HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: empty sFlvToken');
    final wsTime = _wsTime(_parseMap(token.trim())['wsTime']);
    if (wsTime == null) {
      throw const HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: sFlvToken without wsTime');
    }
    var invalidAt = wsTime.add(const Duration(minutes: 5));
    if (expireTime > 0) {
      final bound = expireTime > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(min(expireTime, 8640000000000000), isUtc: true)
          : expireTime > 1000000000
          ? DateTime.fromMillisecondsSinceEpoch(expireTime * 1000, isUtc: true)
          : receivedAt.toUtc().add(Duration(seconds: expireTime));
      if (bound.isBefore(invalidAt)) invalidAt = bound;
    }
    return (refreshAt: invalidAt.subtract(const Duration(seconds: 30)), invalidAt: invalidAt);
  }

  /// `liveui.getCdnTokenInfoEx` with `GetCdnTokenExReq` (0 sFlvUrl,
  /// 1 sStreamName, 2 iLoopTime, 3 tId, 4 iAppId), as the WUP bytes to POST.
  static Uint8List cdnTokenRequest({
    required String flvUrl,
    required String streamName,
    required HuyaUserId userId,
    int loopTime = 0,
    int appId = HuyaEndpoints.tokenAppId,
  }) => WupPacket(
    servant: 'liveui',
    function: 'getCdnTokenInfoEx',
    params: {
      'tReq': WupPacket.structParam(
        (writer) => writer
          ..writeString(0, flvUrl)
          ..writeString(1, streamName)
          ..writeInt(2, loopTime)
          ..writeStruct(3, userId.writeTo)
          ..writeInt(4, appId),
      ),
    },
  ).encode();

  /// The `getCdnTokenInfoEx` answer: the return code, and `GetCdnTokenExResp`
  /// (tag 0 sFlvToken, tag 1 iExpireTime). 5xx is network, another status or
  /// undecodable bytes api-changed.
  static ({int code, String token, int expireTime}) cdnTokenResponse(List<int> bytes, {int status = 200}) {
    if (status >= 500) throw HuyaFailure(HuyaFailureKind.network, 'getCdnTokenInfoEx: HTTP $status');
    if (status != 200) throw HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: HTTP $status');
    final WupPacket packet;
    try {
      packet = WupPacket.decode(bytes);
    } on FormatException catch (error) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: ${error.message}');
    }
    final code = packet.code;
    TarsStruct? rsp;
    try {
      rsp = packet.struct('tRsp');
    } on FormatException {
      throw const HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: tRsp is not Tars');
    }
    if (code == 0 && rsp == null) throw const HuyaFailure(HuyaFailureKind.apiChanged, 'getCdnTokenInfoEx: no tRsp');
    return (code: code, token: (rsp?.string(0) ?? '').trim(), expireTime: rsp?.integer(1) ?? 0);
  }
}

bool _isHuyaHost(String host) {
  final lower = host.toLowerCase();
  return lower == 'huya.com' || lower.endsWith('.huya.com');
}

/// A query split without decoding (tokens may carry stray `%`); the first
/// value of a repeated key wins.
List<({String key, String value, String raw})> _parse(String query) {
  final params = <({String key, String value, String raw})>[];
  final seen = <String>{};
  for (final segment in query.trim().split('&')) {
    if (segment.isEmpty) continue;
    final separator = segment.indexOf('=');
    final key = separator < 0 ? segment : segment.substring(0, separator);
    if (!seen.add(key)) continue;
    params.add((key: key, value: separator < 0 ? '' : segment.substring(separator + 1), raw: segment));
  }
  return params;
}

Map<String, String> _parseMap(String query) => {for (final param in _parse(query)) param.key: param.value};

/// `wsTime`: hexadecimal Unix seconds; null when missing or invalid.
DateTime? _wsTime(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '', radix: 16);
  if (seconds == null || seconds <= 0 || seconds > 0xFFFFFFFFFF) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

DateTime? _earliest(Iterable<DateTime?> values) {
  DateTime? result;
  for (final value in values) {
    if (value != null && (result == null || value.isBefore(result))) result = value;
  }
  return result;
}
