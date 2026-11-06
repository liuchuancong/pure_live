import 'package:live_sites/src/common/quality_label.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One `video_play_url` answer and when it arrived (its leases count from
/// there).
typedef CcPlayAnswer = ({Map<String, dynamic> data, DateTime issuedAt});

/// What 3.x's streams are made of, apart from the room's identity (3.x kept
/// them in `data` and `link`; this adapter rides them on the room's runtime
/// handle): the live channel's tier list and the redirect playlist its
/// signatures are appended to. Rooms without a live channel (offline,
/// refreshed without one, list cards) have none.
@immutable
final class CcRoomData {
  /// Creates the data.
  const CcRoomData({this.streams, this.playlist});

  /// The channel's `quickplay`, else its `stream_list`: tier → CDN → URL or
  /// signature.
  final Map<String, dynamic>? streams;

  /// The channel's `m3u8`: `cgi.v.cc.163.com/redirect/video/{ccid}.m3u8`.
  final String? playlist;
}

/// Pure parsing of NetEase CC streams: the `video_play_url` answer's real
/// tiers (9-1) and its lines with their CDN expansion, leases and media
/// headers; 3.x's stream-list tiers as the fallback.
abstract final class CcPlayParser {
  /// `vapi.cc.163.com/video_play_url/{ccid}` → its object. HTTP 410
  /// (`Gone`, "no live") and 404 are stream-unavailable.
  static Map<String, dynamic> playData(String body, {int status = 200}) {
    if (status == 410 || status == 404) {
      throw CcFailure(CcFailureKind.streamUnavailable, 'video_play_url: HTTP $status');
    }
    final data = CcJson.object(CcJson.decode(body, status: status, what: 'video_play_url'));
    if (data == null) {
      throw CcFailure(CcFailureKind.apiChanged, 'video_play_url: not an object (${CcJson.snippet(body)})');
    }
    return data;
  }

  /// The qualities users pick from (9-1): `vbrname_list` in the server's
  /// order, best first (`vbrname_sel` alone when the list is empty), each a
  /// different stream. The id and the line request's `vbrname` are the tier
  /// code (`original`, `blueray_5M_avc`, `ultra`, `high`, `standard`, …);
  /// the platform order is `total − index`, best first. The label is the
  /// site's own name (`vbrname_mapping`: 原画, 蓝光5M, 超清, 高清, 标清), else
  /// its usual name for the code; the source `original` is always 原画 (the
  /// unified naming rule).
  static List<LivePlayQuality> qualities(Map<String, dynamic> data) {
    final codes = [for (final raw in CcJson.list(data['vbrname_list'])) ?CcJson.string(raw)];
    if (codes.isEmpty) {
      final selected = CcJson.string(data['vbrname_sel']);
      if (selected == null) {
        throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no vbrname_list or vbrname_sel');
      }
      codes.add(selected);
    }
    final names = CcJson.fields(data['vbrname_mapping']);
    final unique = codes.toSet().toList();
    return [
      for (final (index, code) in unique.indexed)
        LivePlayQuality.of(
          label: LiveQualityLabel.normalize(
            platform: ccSiteId,
            rawLabel: code == 'original'
                ? '原画'
                : CcJson.string(names[code]) ?? CcEndpoints.siteQualityNames[code] ?? code,
            id: code,
          ),
          qualityId: code,
          platformOrder: unique.length - index,
        ),
    ];
  }

  /// The CDN codes of `cdn_list` that the answer's own lines do not cover;
  /// each is asked for once more with `cdn={code}`.
  static List<String> uncoveredCdns(Map<String, dynamic> data) {
    final covered = {for (final line in _answerLines(data)) line.cdn};
    return [
      for (final raw in CcJson.list(data['cdn_list']))
        if (CcJson.string(raw) case final code? when covered.add(code)) code,
    ];
  }

  /// The lines of the play answers for one quality: [answers] first the
  /// answer to the quality request, then the ones for the other CDNs.
  ///
  /// An answer has `videourl` on `cdn_sel` and `bakvideourl` on
  /// `bakcdn_sel`. The first answer's `vbrname_sel` is the tier served; a
  /// CDN answer at another tier is dropped, and each CDN code (the line
  /// label) is kept once: a server answering `cdn=hs` with ali again gives
  /// no invented hs line. Every line carries the media headers for [roomId]
  /// and the lease of its `auth_key`. An answer without any URL is
  /// api-changed.
  static List<LivePlayLine> lines(List<CcPlayAnswer> answers, {required String roomId}) {
    if (answers.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no answer');
    final applied = CcJson.string(answers.first.data['vbrname_sel']);
    final headers = CcEndpoints.mediaHeaders(roomId);
    final cdns = <String>{};
    final urls = <String>{};
    final lines = <LivePlayLine>[
      for (final (index, answer) in answers.indexed)
        if (index == 0 || CcJson.string(answer.data['vbrname_sel']) == applied)
          for (final line in _answerLines(answer.data))
            if (cdns.add(line.cdn) && urls.add(line.url.toString()))
              LivePlayLine.of(
                url: line.url.toString(),
                headers: headers,
                format: CcEndpoints.formatOf(line.url),
                formatSource: LivePlayFormatSource.inferred,
                lineLabel: line.cdn,
                lease: ccAuthKeyLease(line.url, answer.issuedAt),
              ),
    ];
    if (lines.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no playable URL');
    return lines;
  }

  static List<({String cdn, Uri url})> _answerLines(Map<String, dynamic> data) => [
    for (final (urlKey, cdnKey) in const [('videourl', 'cdn_sel'), ('bakvideourl', 'bakcdn_sel')])
      if (CcJson.url(data[urlKey]) case final url?) (cdn: CcJson.string(data[cdnKey]) ?? url.host, url: url),
  ];

  // 3.x's streams: the fallback ------------------------------------------------

  /// 3.x's qualities of a live channel (`getPlayQualites`): one per tier of
  /// the room data's streams (`stream_list`: `original`, `high`, `medium`, `low`),
  /// named by 3.x's table (原画, 高清, 标准, 低清), best first. The quality's
  /// id is the tier code. Its lines are the redirect playlist with the
  /// tier's CDN signature appended (`hs`, `ks`, `ali`, `fws`, `wy` first),
  /// or the tier's own URLs ([legacyUrls]).
  ///
  /// The site ignores the appended signature: every tier plays the same
  /// 1 Mbps HLS stream (REG-CC-004). Since 9-1 the qualities come from
  /// `video_play_url` ([qualities], [lines]); these are only the fallback
  /// when that answer fails or cannot be read.
  static List<LivePlayQuality> legacyQualities(CcRoomData data) {
    final raw = data.streams;
    if (raw == null) return const [];
    final live = raw['resolution'] == null;
    final tiers = live ? raw : CcJson.object(raw['resolution']);
    if (tiers == null) return const [];
    final qualities = <(int sort, LivePlayQuality)>[];
    for (final MapEntry(:key, :value) in tiers.entries) {
      final tier = CcJson.object(value);
      if (tier == null) continue;
      if (CcJson.object(tier[live ? 'CDN_FMT' : 'cdn']) == null) continue;
      if (legacyUrls(data, key).isEmpty) continue;
      final kbps = CcJson.integer(tier['vbr']) ?? 0;
      qualities.add((
        _legacySort(key, kbps),
        LivePlayQuality.of(
          label: LiveQualityLabel.normalize(
            platform: ccSiteId,
            rawLabel: CcEndpoints.legacyQualityNames[key] ?? key,
            id: key,
            bitrate: kbps > 0 ? kbps * 1000 : null,
          ),
          qualityId: key,
          platformOrder: _legacySort(key, kbps),
        ),
      ));
    }
    return [for (final (_, quality) in qualities..sort((a, b) => b.$1.compareTo(a.$1))) quality];
  }

  /// The lines of a [legacyQualities] quality: its URLs as they are, each
  /// with the media headers for [roomId] and its format; no lease (every
  /// open asks the redirect again). The quality is assumed applied, as 3.x
  /// did. An empty list is the caller's stream-unavailable.
  static List<LivePlayLine> legacyLines(CcRoomData data, String tier, {required String roomId}) {
    final headers = CcEndpoints.mediaHeaders(roomId);
    return [
      for (final url in legacyUrls(data, tier))
        LivePlayLine.of(
          url: url,
          headers: headers,
          format: CcEndpoints.formatOf(Uri.parse(url)),
          formatSource: LivePlayFormatSource.inferred,
        ),
    ];
  }

  /// The URLs of tier [tier]: a live channel's redirect playlist ([CcRoomData
  /// .playlist]) with the tier's CDN signatures appended, or a `quickplay`
  /// tier's own URLs, 3.x's preferred CDNs (`hs`, `ks`, `ali`, `fws`, `wy`)
  /// first.
  static List<String> legacyUrls(CcRoomData data, String tier) {
    final raw = data.streams;
    if (raw == null) return const [];
    final live = raw['resolution'] == null;
    final tiers = live ? raw : CcJson.object(raw['resolution']);
    final cdns = CcJson.object(CcJson.object(tiers?[tier])?[live ? 'CDN_FMT' : 'cdn']);
    if (cdns == null) return const [];
    final base = data.playlist?.trim() ?? '';
    final preferred = <String>[];
    final others = <String>[];
    for (final MapEntry(key: cdn, value: suffix) in cdns.entries) {
      final url = live && base.isNotEmpty ? _signedPlaylist(base, suffix) : _directUrl(suffix);
      if (Uri.tryParse(url)?.hasScheme != true) continue;
      final target = _preferredCdns.contains(cdn.toLowerCase()) ? preferred : others;
      if (!target.contains(url)) target.add(url);
    }
    return [...preferred, ...others];
  }

  /// CDNs whose lines 3.x put first.
  static const List<String> _preferredCdns = ['hs', 'ks', 'ali', 'fws', 'wy'];

  /// 3.x's order: the tier's rank (a missing `vbr` must not demote 原画),
  /// then the bitrate; unknown tiers by bitrate alone.
  static int _legacySort(String code, int kbps) {
    final rank = switch (code.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '')) {
      'blueray' || 'original' || 'origin' || 'source' => 6,
      'ultra' => 5,
      'high' || 'hd' => 4,
      'medium' || 'standard' || 'sd' => 3,
      'low' || 'ld' => 2,
      _ => 0,
    };
    return rank == 0 ? kbps : rank * 1000000 + kbps.clamp(0, 999999);
  }

  /// [base] with a `CDN_FMT` value: a protocol-relative or absolute http(s)
  /// URL as it is, a signature appended to the query, nothing for another
  /// scheme (3.x's `_resolveLiveCdnUrl`).
  static String _signedPlaylist(String base, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.startsWith('//')) return 'https:$text';
    final direct = Uri.tryParse(text);
    if (direct != null && direct.hasScheme) {
      return const {'http', 'https'}.contains(direct.scheme.toLowerCase()) ? text : '';
    }
    if (text.isEmpty) return base;
    return '$base${base.contains('?') ? '&' : '?'}${text.replaceFirst(RegExp('^[?&]+'), '')}';
  }

  static String _directUrl(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.startsWith('//') ? 'https:$text' : text;
  }
}

/// The lease of a media URL received at [issuedAt], from the first field of
/// its `auth_key` (`{Unix seconds}-{rand}-{uid}-{md5}`, 300 seconds after
/// issue): renew [CcEndpoints.leaseLead] (at most a quarter of the lifetime)
/// before. Expiry refuses new connections only; an established one keeps
/// flowing. No key, or one already past, is no lease.
LivePlayLease? ccAuthKeyLease(Uri url, DateTime issuedAt) {
  final match = RegExp(r'(?:^|&)auth_key=(\d+)-').firstMatch(url.query);
  final expires = match == null ? null : int.tryParse(match.group(1)!);
  if (expires == null || expires <= 0) return null;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
  final lifetime = expiresAt.difference(issuedAt);
  if (lifetime <= Duration.zero) return null;
  final quarter = lifetime ~/ 4;
  final lead = quarter < CcEndpoints.leaseLead ? quarter : CcEndpoints.leaseLead;
  return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
}
