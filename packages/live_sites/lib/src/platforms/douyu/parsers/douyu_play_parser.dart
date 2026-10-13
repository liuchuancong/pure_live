import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/infer_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_json.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's play-request signing descriptor (`getEncryption`; reference
/// `DouyuDescriptor`). Signs one form per (room, rate, cdn); reused across
/// requests by the adapter while it stays fresh.
final class DouyuDescriptor {
  /// Creates a DouyuDescriptor.
  const DouyuDescriptor({
    required this.key,
    required this.randStr,
    required this.encData,
    required this.encTime,
    required this.expireAt,
    required this.isSpecial,
  });

  /// Reads the `data` object; null when a field is missing or blank, or
  /// `enc_time` is outside 1–16. Numbers may be strings.
  static DouyuDescriptor? fromJson(Object? value) {
    if (value is! Map) return null;
    final key = jsonString(value['key']);
    final randStr = jsonString(value['rand_str']);
    final encData = jsonString(value['enc_data']);
    final encTime = jsonInt(value['enc_time']);
    final expireAt = jsonInt(value['expire_at']);
    if (key == null || randStr == null || encData == null || encTime == null || expireAt == null) return null;
    if (encTime < 1 || encTime > 16) return null;
    return DouyuDescriptor(
      key: key,
      randStr: randStr,
      encData: encData,
      encTime: encTime,
      expireAt: DateTime.fromMillisecondsSinceEpoch(expireAt * 1000, isUtc: true),
      isSpecial: jsonInt(value['is_special']) == 1,
    );
  }

  /// Signing key.
  final String key;

  /// Initial secret.
  final String randStr;

  /// Passed through to the play form as is.
  final String encData;

  /// Hashing rounds, 1–16.
  final int encTime;

  /// When the platform stops accepting it (UTC).
  final DateTime expireAt;

  /// Special descriptors sign without the room id and time.
  final bool isSpecial;

  /// Usable when it expires more than [lead] after [now].
  bool usableAt(DateTime now, {Duration lead = const Duration(seconds: 30)}) => expireAt.isAfter(now.add(lead));

  /// `auth` for room [roomId] at Unix second [tt]: `rand_str` hashed with
  /// the key [encTime] times, then md5 of secret + key + rid + tt (without
  /// rid and tt when [isSpecial]).
  String auth(String roomId, int tt) {
    var secret = randStr;
    for (var round = 0; round < encTime; round++) {
      secret = md5.convert(utf8.encode('$secret$key')).toString();
    }
    final salt = isSpecial ? '' : '$roomId$tt';
    return md5.convert(utf8.encode('$secret$key$salt')).toString();
  }
}

/// What one quality option carries between `getQualities` and `getLines`:
/// the opaque `rate` request code and the CDN codes to sign it on, in line
/// order (reference `DouyuPlayData`).
final class DouyuPlayData {
  /// Carries the rate and its CDN set.
  DouyuPlayData(this.rate, List<String> cdns) : cdns = List.unmodifiable(cdns);

  /// Request code (`0` is usually source, `-1` lets the server choose);
  /// never a bitrate, never compared by size.
  final int rate;

  /// CDN codes, one line each; `''` lets the server pick.
  final List<String> cdns;

  @override
  String toString() => 'DouyuPlayData($rate, $cdns)';
}

/// Pure parsing of the play path (`getEncryption`, `getH5PlayV1`;
/// reference `DouyuApi`). Throws [DouyuFailure] on shape changes.
abstract final class DouyuPlayParser {
  /// How long before `expire` a play URL is renewed (at most a quarter of
  /// its lifetime).
  static const Duration leaseLead = Duration(seconds: 45);

  /// The lifetime assumed, with forced renewal on, for a FLV URL that
  /// states none (`expire=0`), which the CDN may still cut on its own
  /// schedule.
  static const Duration forcedLeaseLifetime = Duration(minutes: 5);

  /// A descriptor closer than this to its `expire_at` is not used.
  static const Duration descriptorMargin = Duration(seconds: 30);

  /// `getEncryption`: the descriptor, which must be complete and usable at
  /// [now]; anything else is apiChanged.
  static DouyuDescriptor descriptor(String body, {required DateTime now, int status = 200}) {
    final root = checkedEnvelope(body, status: status, what: 'getEncryption');
    final descriptor = DouyuDescriptor.fromJson(root['data']);
    if (descriptor == null || !descriptor.usableAt(now)) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'getEncryption: descriptor incomplete or expired');
    }
    return descriptor;
  }

  /// The `getH5PlayV1` form for room [roomId] at Unix second [tt]. [did]
  /// must be the one the descriptor was issued for and the cookie carries.
  /// Only AVC is asked for (`hevc=0`).
  static Map<String, String> signedForm(
    DouyuDescriptor descriptor, {
    required String roomId,
    required int tt,
    required String did,
    int rate = -1,
    String cdn = '',
  }) => {
    'enc_data': descriptor.encData,
    'tt': '$tt',
    'did': did,
    'auth': descriptor.auth(roomId, tt),
    'cdn': cdn,
    'rate': '$rate',
    'hevc': '0',
    'fa': '0',
    'ive': '0',
    'ver': 'Douyu_new',
    'iar': '0',
  };

  /// `getH5PlayV1` → its `data`. HTTP 403 (the edge's bare 鉴权失败) is risk
  /// control; `error != 0` (`-5` 房间未开播) is stream-unavailable, which a
  /// retry cannot fix; no `data` is apiChanged. `error` may be a string;
  /// without `error` the `code` counts.
  static Map<String, dynamic> playData(String body, {int status = 200}) {
    statusChecks(status, 'getH5PlayV1', body);
    final decoded = decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, 'getH5PlayV1: HTTP $status, not an object');
    }
    final code = jsonInt(decoded['error'] ?? decoded['code']);
    if (code == null) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'getH5PlayV1: no error code');
    }
    if (code != 0) {
      throw DouyuFailure(
        DouyuFailureKind.streamUnavailable,
        'getH5PlayV1: error $code ${jsonString(decoded['msg']) ?? ''}'.trim(),
      );
    }
    final data = jsonObject(decoded['data']);
    if (data == null || status < 200 || status >= 300) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, 'getH5PlayV1: HTTP $status, no data');
    }
    return data;
  }

  /// Qualities of a metadata answer (`rate=-1`): `multirates` in the
  /// platform's order (never sorted: `rate` is a request code), first of a
  /// rate wins, each carrying [DouyuPlayData] with the answer's [cdns].
  /// Without `multirates`, one default option for `data.rate`.
  ///
  /// `streamStatus: 0` is stream-unavailable: the room is on air but no
  /// stream is pushed, and the URL it still carries answers 404 on every
  /// CDN. Only the metadata answer is judged.
  static List<LivePlayQuality> qualities(Map<String, dynamic> data) {
    if (jsonInt(data['streamStatus']) == 0) {
      throw const DouyuFailure(DouyuFailureKind.streamUnavailable, 'getH5PlayV1: streamStatus 0 (no stream pushed)');
    }
    final items = [for (final raw in jsonList(data['multirates'])) ?jsonObject(raw)];
    final seen = <int>{};
    final qualities = <LivePlayQuality>[
      for (final (index, item) in items.indexed)
        if (jsonInt(item['rate']) case final rate? when seen.add(rate))
          LivePlayQuality(
            label: jsonString(item['name']) ?? '',
            qualityId: '$rate',
            platformOrder: items.length - index,
          ),
    ];
    if (qualities.isNotEmpty) return qualities;
    final rate = jsonInt(data['rate']) ?? -1;
    return [LivePlayQuality(label: 'default', qualityId: '$rate', platformOrder: 1)];
  }

  /// CDN codes: `cdnsWithName` in order without duplicates, the answering
  /// `rtmp_cdn` first when it is missing, `scdn*` codes last; `['']` (the
  /// server picks) when there are none. A line's identity is its code,
  /// never its index.
  static List<String> cdns(Map<String, dynamic> data) {
    final codes = <String>[];
    for (final item in jsonList(data['cdnsWithName'])) {
      final code = jsonString(jsonObject(item)?['cdn']);
      if (code != null && !codes.contains(code)) codes.add(code);
    }
    final current = jsonString(data['rtmp_cdn']);
    if (current != null && !codes.contains(current)) codes.insert(0, current);
    if (codes.isEmpty) return const [''];
    return [...codes.where((code) => !code.startsWith('scdn')), ...codes.where((code) => code.startsWith('scdn'))];
  }

  /// The rate the server delivered: an integer of 0 or more; missing,
  /// negative, fractional or text is unconfirmed (null), never truncated
  /// into source quality.
  static int? confirmedRate(Map<String, dynamic> data) => switch (jsonInt(data['rate'])) {
    final int rate when rate >= 0 => rate,
    _ => null,
  };

  /// The media URL of a play answer, entities decoded, or null: an
  /// absolute `rtmp_live` as is; else `rtmp_url` (then `flv_url`) joined
  /// with `rtmp_live`; else `player_1`, `stream_url` or `url`; else an
  /// `flv_url` ending in `.flv`, `.m3u8` or `.mp4`. A CDN base alone is
  /// never media.
  static String? mediaUrl(Map<String, dynamic> data) {
    String field(String key) => decodeHtmlEntities(jsonString(data[key]) ?? '');
    final live = field('rtmp_live');
    if (_playable(live)) return live;
    for (final key in const ['rtmp_url', 'flv_url']) {
      final base = field(key);
      if (base.isEmpty || live.isEmpty) continue;
      final joined = '${base.replaceFirst(RegExp(r'/+$'), '')}/${live.replaceFirst(RegExp('^/+'), '')}';
      if (_playable(joined)) return joined;
    }
    for (final key in const ['player_1', 'stream_url', 'url']) {
      final value = field(key);
      if (_playable(value)) return value;
    }
    final flv = field('flv_url');
    final path = Uri.tryParse(flv)?.path.toLowerCase() ?? '';
    if (_playable(flv) && (path.endsWith('.flv') || path.endsWith('.m3u8') || path.endsWith('.mp4'))) return flv;
    return null;
  }

  /// One CDN's answer as a [LivePlayLine] of room [roomId] signed at
  /// [issuedAt], with the rate the server confirmed. The format is
  /// inferred from the URL (douyu does not declare it). No media URL is
  /// apiChanged.
  static ({LivePlayLine line, int? rate}) answer(
    Map<String, dynamic> data, {
    required String roomId,
    required String cdn,
    required String cookie,
    required DateTime issuedAt,
    bool forceRenewal = false,
  }) {
    final url = mediaUrl(data);
    if (url == null) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'getH5PlayV1: no playable URL');
    }
    final format = inferStreamFormat(url) ?? LiveStreamFormat.other;
    return (
      line: LivePlayLine(
        url: url,
        headers: mediaHeaders(roomId, cookie: cookie),
        format: format,
        formatSource: LivePlayFormatSource.inferred,
        lineLabel: cdn.isEmpty ? null : cdn,
        lease: lease(url, issuedAt, forceRenewal: forceRenewal),
      ),
      rate: confirmedRate(data),
    );
  }

  /// The lifetime a media URL states: its `expire` seconds when above 0
  /// (there is no absolute time in the URL); null for `expire=0` or none.
  static Duration? statedLifetime(String url) {
    final query = Uri.tryParse(url)?.query ?? '';
    final expire = int.tryParse(RegExp(r'(?:^|&)expire=(\d+)(?:&|$)').firstMatch(query)?.group(1) ?? '');
    return expire == null || expire <= 0 ? null : Duration(seconds: expire);
  }

  /// The lease of a media URL issued at [issuedAt]: its [statedLifetime];
  /// with [forceRenewal], a FLV URL that states none gets
  /// [forcedLeaseLifetime]. Renew [leaseLead] (at most a quarter of the
  /// lifetime) before. Expiry closes the established connection, so the
  /// renewed stream is spliced in.
  static LivePlayLease? lease(String url, DateTime issuedAt, {bool forceRenewal = false}) {
    final lifetime =
        statedLifetime(url) ??
        (forceRenewal && (Uri.tryParse(url)?.path.toLowerCase().endsWith('.flv') ?? false)
            ? forcedLeaseLifetime
            : null);
    if (lifetime == null) return null;
    final expiresAt = issuedAt.toUtc().add(lifetime);
    final quarter = Duration(seconds: lifetime.inSeconds ~/ 4);
    return LivePlayLease(
      refreshAt: expiresAt.subtract(quarter < leaseLead ? quarter : leaseLead),
      expiresAt: expiresAt,
      requiresReconnect: true,
    );
  }

  /// Media request headers for room [roomId], shared by playback and
  /// recording: Origin, the room's Referer, UA and the DID cookie.
  static Map<String, String> mediaHeaders(String roomId, {required String cookie}) => {
    'origin': 'https://www.douyu.com',
    'referer': 'https://www.douyu.com/$roomId',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/128.0.0.0 Safari/537.36',
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Status codes the play endpoint shares with the other endpoints.
  static void statusChecks(int status, String what, String body) => DouyuRoomParser.statusChecks(status, what, body);

  /// The `{error|code, msg, data}` envelope.
  static Map<String, dynamic> checkedEnvelope(String body, {required int status, required String what}) =>
      DouyuRoomParser.checked(body, status: status, what: what);

  static bool _playable(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.host.isNotEmpty && const {'http', 'https', 'rtmp'}.contains(uri.scheme.toLowerCase());
  }
}
