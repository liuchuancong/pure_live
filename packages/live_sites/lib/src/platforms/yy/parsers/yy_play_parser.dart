import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/infer_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';

/// One answer of the anonymous mobile HLS route: the playlist and the stream
/// it serves.
typedef YyMobileHls = ({Uri url, int width, int height, String video});

/// One mobile HLS answer asked for: the rate and what it served.
typedef YyMobileAnswer = ({String rate, YyMobileHls? hls});

/// Pure parsing of YY's streams: the stream-manager answer (its qualities,
/// its FLV lines and the CDN lines behind them, and the lease of a FLV URL)
/// and the mobile HLS route. Everything throws [YyFailure]s.
abstract final class YyPlayParser {
  // Stream-manager ------------------------------------------------------------

  /// A stream-manager answer: any non-2xx, a body that is not a JSON object
  /// — api-changed (429, 401/403, 5xx as the status gates say).
  static Map<String, dynamic> streams(String body, {int status = 200}) {
    final root = YyJson.object(YyJson.decoded(body, status: status, what: 'stream-manager'));
    if (root == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'stream-manager: not a JSON object (${YyJson.snippet(body)})');
    }
    return root;
  }

  /// The qualities of a stream-manager answer (3.x's `parsePlayQualities`):
  /// each stream's `json` holds `gear_info` (`gear`, `name`) and `rate`;
  /// the first stream of a gear wins, a name used by two gears gets the
  /// gear appended, best rate first. Only streams with a `stream_key` are
  /// listed: the others (`mix` 1) have no web stream, and asking for their
  /// gear is answered with another gear's stream.
  static List<LivePlayQuality> qualities(Map<String, dynamic> streams) {
    final records = <({String name, String gear, int rate})>[];
    final seen = <String>{};
    for (final stream in _streams(streams)) {
      if (YyJson.text(stream.raw['stream_key']).isEmpty) continue;
      final info = YyJson.object(stream.json?['gear_info']);
      final name = YyJson.text(info?['name']);
      final gear = YyJson.text(info?['gear']);
      if (name.isEmpty || gear.isEmpty || !seen.add(gear)) continue;
      records.add((name: name, gear: gear, rate: YyJson.integer(stream.json?['rate']) ?? 0));
    }
    final names = <String, int>{};
    for (final record in records) {
      names.update(record.name, (count) => count + 1, ifAbsent: () => 1);
    }
    return [
      for (final record in records)
        LivePlayQuality.of(
          label: names[record.name] == 1 ? record.name : '${record.name} · ${record.gear}',
          qualityId: record.gear,
          platformOrder: record.rate,
        ),
    ]..sort((left, right) => right.platformOrder.compareTo(left.platformOrder));
  }

  /// The lines of a stream-manager answer received at [issuedAt]: every
  /// `stream_line_addr` URL in server order (3.x's `parsePlayUrls`), FLV,
  /// with the media headers, the CDN line (`line_seq`) as line label and the
  /// lease of `t`. The applied quality is the gear of the stream the server
  /// chose (asking for a gear without a web stream is answered with
  /// another), or null when it names none.
  static ({List<LivePlayLine> lines, String? appliedGear}) resolution(
    Map<String, dynamic> streams, {
    required DateTime issuedAt,
    String cookie = '',
  }) {
    final gears = <String, String>{};
    for (final stream in _streams(streams)) {
      final key = YyJson.text(stream.raw['stream_key']);
      final gear = YyJson.text(YyJson.object(stream.json?['gear_info'])?['gear']);
      if (key.isNotEmpty && gear.isNotEmpty) gears[key] = gear;
    }
    final headers = YyEndpoints.mediaHeaders(cookie: cookie);
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    String? applied;
    final addresses = YyJson.object(YyJson.object(streams['avp_info_res'])?['stream_line_addr']);
    for (final MapEntry(:key, :value) in (addresses ?? const <String, dynamic>{}).entries) {
      final address = YyJson.object(value);
      var url = YyJson.text(YyJson.object(address?['cdn_info'])?['url']);
      if (url.startsWith('//')) url = 'https:$url';
      final uri = YyJson.url(url);
      if (uri == null || url.isEmpty || !(uri.isScheme('https') || uri.isScheme('http')) || !seen.add(url)) {
        continue;
      }
      applied ??= gears[key];
      lines.add(
        LivePlayLine.of(
          url: url,
          format: inferStreamFormat(url) ?? LiveStreamFormat.other,
          formatSource: LivePlayFormatSource.inferred,
          headers: headers,
          lineLabel: YyJson.text(address?['line_seq']).isEmpty ? uri.host : YyJson.text(address?['line_seq']),
          lease: lease(uri, issuedAt),
        ),
      );
    }
    return (lines: lines, appliedGear: applied);
  }

  /// The other CDN lines (`line_seq`) the served stream is on, in server
  /// order: `stream_line_list` of the served `stream_key`, without the lines
  /// it was served on. One more request each (asking the served gear on that
  /// line) gives the stream there.
  static List<int> otherLines(Map<String, dynamic> streams) {
    final avp = YyJson.object(streams['avp_info_res']);
    final addresses = YyJson.object(avp?['stream_line_addr']);
    if (addresses == null || addresses.isEmpty) return const [];
    final served = {for (final value in addresses.values) ?YyJson.integer(YyJson.object(value)?['line_seq'])};
    final infos = YyJson.object(YyJson.object(avp?['stream_line_list'])?[addresses.keys.first])?['line_infos'];
    final lines = <int>[];
    for (final raw in YyJson.list(infos)) {
      final line = YyJson.integer(YyJson.object(raw)?['line_seq']);
      if (line != null && line >= 0 && !served.contains(line) && !lines.contains(line)) lines.add(line);
    }
    return lines;
  }

  /// [first] followed by the lines of [others] (the answers on
  /// [otherLines]) that serve the same gear, each with its own lease: one
  /// quality, several CDN lines backing each other up. An answer serving
  /// another gear, and a [first] whose gear is unknown, add nothing.
  static List<LivePlayLine> withLines(
    ({List<LivePlayLine> lines, String? appliedGear}) first,
    Iterable<({List<LivePlayLine> lines, String? appliedGear})> others,
  ) {
    final applied = first.appliedGear;
    if (applied == null) return first.lines;
    final seen = {for (final line in first.lines) line.url};
    return [
      ...first.lines,
      for (final other in others)
        if (other.appliedGear == applied)
          for (final line in other.lines)
            if (seen.add(line.url)) line,
    ];
  }

  /// The lease of a FLV URL received at [issuedAt]: `t` is the Unix second
  /// its signature stops opening connections (issue + 600 s); renew
  /// [YyEndpoints.leaseLead] (at most a quarter of the lifetime) before. An
  /// open connection keeps flowing past it. No `t`, or one already past, is
  /// no lease. Mobile HLS URLs carry the issue time in `t`, not an expiry:
  /// they get none.
  static LivePlayLease? lease(Uri url, DateTime issuedAt, {bool allowExpired = false}) {
    if (url.path.toLowerCase().endsWith('.m3u8')) return null;
    final expiry = int.tryParse(url.queryParameters['t'] ?? '');
    if (expiry == null || expiry < 1000000000) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) {
      return allowExpired
          ? LivePlayLease.of(refreshAt: expiresAt.subtract(YyEndpoints.leaseLead), expiresAt: expiresAt)
          : null;
    }
    final quarter = lifetime ~/ 4;
    final lead = quarter < YyEndpoints.leaseLead ? quarter : YyEndpoints.leaseLead;
    return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  // Mobile HLS ----------------------------------------------------------------

  /// A mobile HLS answer (`hls/new/get/<sid>/<ssid>/<rate>`, JSONP-like
  /// `({…})`): the playlist and the stream it serves, or null when the
  /// channel has none (`code` not 0, or no http(s) `hls`: an offline
  /// channel).
  static YyMobileHls? mobileHls(String body, {int status = 200}) {
    YyJson.checkPage(status, 'mobile HLS');
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    Object? decoded;
    if (start >= 0 && end > start) {
      try {
        decoded = jsonDecode(body.substring(start, end + 1));
      } on FormatException {
        decoded = null;
      }
    }
    final data = YyJson.object(decoded);
    if (data == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'mobile HLS: no JSON object (${YyJson.snippet(body)})');
    }
    if (YyJson.integer(data['code']) != 0) return null;
    final url = YyJson.url(YyJson.text(data['hls']));
    if (url == null || !url.isScheme('https') && !url.isScheme('http')) return null;
    return (
      url: url,
      width: YyJson.integer(data['width']) ?? 0,
      height: YyJson.integer(data['height']) ?? 0,
      video: YyJson.text(data['video']),
    );
  }

  /// The qualities of the mobile HLS answers by rate (3.x's
  /// `_getMobileHlsQualities`): 1200 is 流畅 and 4000 高清, with the short
  /// edge (`流畅 · 360p`); rates that serve the same stream keep the later
  /// (higher) request; best first.
  static List<LivePlayQuality> mobileQualities(List<YyMobileAnswer> answers) {
    final byStream = <String, LivePlayQuality>{};
    for (final (:rate, :hls) in answers) {
      final hlsAnswer = hls;
      if (hlsAnswer == null) continue;
      final shortEdge = hlsAnswer.width > 0 && hlsAnswer.height > 0
          ? (hlsAnswer.width < hlsAnswer.height ? hlsAnswer.width : hlsAnswer.height)
          : 0;
      final identity = hlsAnswer.video.isNotEmpty ? hlsAnswer.video : '${hlsAnswer.width}x${hlsAnswer.height}';
      final tier = rate == YyEndpoints.mobileHlsRates.first ? '流畅' : '高清';
      byStream[identity] = LivePlayQuality.of(
        label: '$tier${shortEdge > 0 ? ' · ${shortEdge}p' : ''}',
        qualityId: '${YyEndpoints.mobileHlsPrefix}$rate',
        platformOrder: int.tryParse(rate) ?? 0,
      );
    }
    return byStream.values.toList()..sort((left, right) => right.platformOrder.compareTo(left.platformOrder));
  }

  /// The one HLS line of a mobile answer, with the media headers.
  static LivePlayLine mobileLine(YyMobileHls hls, {String cookie = ''}) => LivePlayLine.of(
    url: hls.url.toString(),
    format: LiveStreamFormat.hls,
    formatSource: LivePlayFormatSource.declared,
    headers: YyEndpoints.mediaHeaders(cookie: cookie),
    lineLabel: hls.url.host,
    geometry: hls.width > 0 && hls.height > 0 ? PlayGeometry.of(width: hls.width, height: hls.height) : null,
  );

  // Helpers -------------------------------------------------------------------

  /// Each `channel_stream_info.streams[]` with its `json` decoded (null when
  /// it is not a JSON object).
  static Iterable<({Map<String, dynamic> raw, Map<String, dynamic>? json})> _streams(
    Map<String, dynamic> streams,
  ) sync* {
    for (final raw in YyJson.list(YyJson.object(streams['channel_stream_info'])?['streams'])) {
      final stream = YyJson.object(raw);
      if (stream == null) continue;
      Object? decoded;
      final text = YyJson.text(stream['json']);
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } on FormatException {
          decoded = null;
        }
      }
      yield (raw: stream, json: YyJson.object(decoded));
    }
  }
}
