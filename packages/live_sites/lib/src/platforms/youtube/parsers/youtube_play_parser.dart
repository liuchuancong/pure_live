import 'dart:math' as math;

import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_json.dart';

/// One `#EXT-X-STREAM-INF` variant of an HLS master: its (already absolute)
/// `url`, `height` and `fps`, the `codec` its `CODECS` names, its `bandwidth`
/// and, when the resolution carried one, its `width`.
typedef YoutubeVariant = ({String url, int? width, int? height, double fps, LiveStreamCodec? codec, int? bandwidth});

/// Pure parsing of YouTube playback: the ANDROID `player` answer's
/// `streamingData` (an `hlsManifestUrl`, a `dashManifestUrl`, progressive
/// `formats`) and the HLS master text fetched from that url. A live broadcast's
/// primary path is the HLS master, whose `#EXT-X-STREAM-INF` variants become the
/// qualities and their one line each; `dash:auto` and the progressive
/// `http:<itag>` tiers are offered alongside.
abstract final class YoutubePlayParser {
  /// How long before a media URL's `expire` it is renewed.
  static const Duration leaseLead = Duration(minutes: 10);

  /// The most variants read from a master (a manifest beyond this is treated as
  /// hostile and truncated).
  static const int maxVariants = 64;

  /// The `#EXT-X-STREAM-INF` variants of [masterText], resolved against
  /// [masterUrl]; at most [maxVariants]. Malformed variant lines are skipped,
  /// never fatal.
  static List<YoutubeVariant> variants(String masterText, Uri masterUrl) {
    // The master is read through the shared HLS parser; a body the parser
    // refuses, or one that is not a master playlist, yields no variants (the
    // tier collapses to `hls:auto` as before). Relative URIs are resolved
    // against the master here so the master's own query is never copied onto
    // a variant.
    final result = parseHlsMaster(masterText, masterUrl: masterUrl);
    final variants = <YoutubeVariant>[];
    for (final parsed in result?.master.variants ?? const <HlsVariant>[]) {
      if (variants.length >= maxVariants) break;
      final uri = resolveHlsVariantUri(parsed.uri, master: masterUrl);
      variants.add((
        url: uri.toString(),
        width: parsed.width,
        height: parsed.height,
        fps: parsed.frameRate ?? 0,
        codec: hlsVideoCodecOf(parsed.codecs),
        bandwidth: parsed.bandwidth,
      ));
    }
    return variants;
  }

  /// The qualities a broadcast offers: the HLS variants (primary), then the
  /// progressive `formats[]`, then a single `dash:auto` when a DASH manifest is
  /// present. An unparseable or empty HLS tier collapses to `hls:auto`
  /// ("HLS 自动"). Best first.
  static List<LivePlayQuality> qualities({
    required List<YoutubeVariant> variants,
    String? hlsManifestUrl,
    String? dashManifestUrl,
    List<Map<String, dynamic>> progressive = const [],
  }) {
    final qualities = <LivePlayQuality>[];
    final seen = <String>{};
    for (final variant in variants) {
      final height = variant.height;
      final id = height == null
          ? 'hls:auto'
          : 'hls:$height:${_fpsPart(variant.fps)}:${variant.codec?.name ?? 'unknown'}';
      if (!seen.add(id)) continue;
      qualities.add(
        LivePlayQuality(label: height == null ? 'HLS 自动' : '${height}p', qualityId: id, codec: variant.codec),
      );
    }
    if (hlsManifestUrl != null && variants.isEmpty) {
      qualities.add(const LivePlayQuality(label: 'HLS 自动', qualityId: 'hls:auto'));
    }
    for (final format in progressive) {
      final itag = jsonString(format['itag']);
      if (itag == null) continue;
      final id = 'http:$itag';
      if (!seen.add(id)) continue;
      final height = jsonInt(format['height']);
      qualities.add(
        LivePlayQuality(
          label: jsonString(format['qualityLabel']) ?? (height == null ? 'MP4 $itag' : '${height}p'),
          qualityId: id,
          codec: _codecOf(format),
        ),
      );
    }
    if (dashManifestUrl != null && seen.add('dash:auto')) {
      qualities.add(const LivePlayQuality(label: 'DASH 自动', qualityId: 'dash:auto'));
    }
    final total = qualities.length;
    return [for (final (index, quality) in qualities.indexed) quality.copyWith(platformOrder: total - index)];
  }

  /// The playable lines for [qualityId] (the default tier when null): the
  /// matching HLS variant, the master for `hls:auto`, the DASH manifest for
  /// `dash:auto`, or the progressive `formats[]` url for `http:<itag>`.
  ///
  /// Every URL is checked against the media host allowlist ([allowlisted]); a
  /// URL that leaves it (or carries user info or a fragment) is an api-changed
  /// failure. Lines carry [YoutubeEndpoints.mediaHeaders] for [videoId] and the
  /// lease read from their own `expire`.
  static List<LivePlayLine> lines({
    required List<YoutubeVariant> variants,
    required String videoId,
    required DateTime issuedAt,
    String? hlsManifestUrl,
    String? dashManifestUrl,
    List<Map<String, dynamic>> progressive = const [],
    String? qualityId,
  }) {
    final headers = YoutubeEndpoints.mediaHeaders(videoId);
    var url = qualityId == null ? '' : qualityId.trim();
    if (url.isEmpty && variants.isNotEmpty) {
      final best = variants.first;
      url = 'hls:${best.height}:${_fpsPart(best.fps)}:${best.codec?.name ?? 'unknown'}';
    } else if (url.isEmpty) {
      url = 'hls:auto';
    }
    if (url.startsWith('dash:')) {
      final dash = dashManifestUrl;
      if (dash == null) return const [];
      return [_line(dash, LiveStreamFormat.dash, headers: headers, issuedAt: issuedAt, lineLabel: 'DASH')];
    }
    if (url.startsWith('http:')) {
      final itag = url.substring('http:'.length);
      for (final format in progressive) {
        if (jsonString(format['itag']) != itag) continue;
        final address = jsonString(format['url']);
        if (address == null) continue;
        final height = jsonInt(format['height']);
        return [
          _line(
            address,
            LiveStreamFormat.mp4,
            headers: headers,
            issuedAt: issuedAt,
            codec: _codecOf(format),
            lineLabel: height == null ? 'MP4 $itag' : '${height}p',
          ),
        ];
      }
      return const [];
    }
    final hls = url.startsWith('hls:') ? url : 'hls:auto';
    if (hls == 'hls:auto') {
      final master = hlsManifestUrl;
      if (master == null) return const [];
      return [_line(master, LiveStreamFormat.hls, headers: headers, issuedAt: issuedAt, lineLabel: 'HLS 自动')];
    }
    for (final variant in variants) {
      final id = 'hls:${variant.height}:${_fpsPart(variant.fps)}:${variant.codec?.name ?? 'unknown'}';
      if (id != hls) continue;
      return [
        _line(
          variant.url,
          LiveStreamFormat.hls,
          headers: headers,
          issuedAt: issuedAt,
          codec: variant.codec,
          lineLabel: '${variant.height}p',
        ),
      ];
    }
    // A named quality the master no longer lists falls back to the master.
    final master = hlsManifestUrl;
    if (master == null) return const [];
    return [_line(master, LiveStreamFormat.hls, headers: headers, issuedAt: issuedAt, lineLabel: 'HLS 自动')];
  }

  /// The lease of a media URL received at [issuedAt]: the `?expire=<epoch s>`
  /// or `/expire/<s>/` deadline, renewed [leaseLead] (at most a quarter of the
  /// remaining lifetime) before. No expiry, or one already past, is no lease.
  static LivePlayLease? lease(Uri url, DateTime issuedAt) {
    final raw = url.queryParameters['expire'] ?? RegExp(r'/expire/(\d+)').firstMatch(url.path)?.group(1);
    final seconds = int.tryParse(raw ?? '');
    if (seconds == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) return null;
    final lead = Duration(microseconds: math.min(leaseLead.inMicroseconds, lifetime.inMicroseconds ~/ 4));
    return LivePlayLease(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  /// One https media URL inside the platform's host allowlist
  /// (`googlevideo.com`, `youtube.com`, `youtube-nocookie.com` and their
  /// subdomains), carrying no user info and no fragment; anything else is an
  /// api-changed failure. Returns the parsed URL.
  static Uri allowlisted(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
      throw const YouTubeFailure(YoutubeFailureKind.apiChanged, 'media: url is not an https origin');
    }
    if (uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const YouTubeFailure(YoutubeFailureKind.apiChanged, 'media: url carries user info or a fragment');
    }
    final host = uri.host.toLowerCase();
    if (!_mediaHosts.any((allowed) => host == allowed || host.endsWith('.$allowed'))) {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, 'media: host $host is not allowlisted');
    }
    return uri;
  }

  /// The `playabilityStatus.status` of a stream request mapped to a failure:
  /// `OK` is playable, everything else (offline, unplayable, login, error) is
  /// the reported reason a room offers no line.
  static void checkStatus(String status) {
    if (status == 'OK') return;
    throw YouTubeFailure(
      status == 'LOGIN_REQUIRED' ? YoutubeFailureKind.riskControl : YoutubeFailureKind.streamUnavailable,
      'player: $status playability',
    );
  }

  // Internals -----------------------------------------------------------------

  static const List<String> _mediaHosts = ['googlevideo.com', 'youtube.com', 'youtube-nocookie.com'];

  static LivePlayLine _line(
    String url,
    LiveStreamFormat format, {
    required Map<String, String> headers,
    required DateTime issuedAt,
    LiveStreamCodec? codec,
    String? lineLabel,
  }) {
    final uri = allowlisted(url);
    return LivePlayLine(
      url: uri.toString(),
      format: format,
      formatSource: LivePlayFormatSource.declared,
      headers: headers,
      codec: codec,
      lineLabel: lineLabel ?? uri.host,
      lease: lease(uri, issuedAt),
    );
  }

  /// The fps token of a quality id: a plain bucket (`fps0`) above 30, else the
  /// rounded frame rate.
  static String _fpsPart(double fps) => fps > 30 ? 'fps0' : '${fps.round()}';

  static LiveStreamCodec? _codecOfCodecs(String codecs) => hlsVideoCodecOf(codecs);

  /// The codec of a progressive `formats[]` entry: its `codecs` hint, else its
  /// `mimetype` (`video/mp4; codecs="avc1…"`), mapped as a CODES string.
  static LiveStreamCodec? _codecOf(Map<String, dynamic> format) {
    final codecs = jsonString(format['codecs']) ?? '';
    if (codecs.isNotEmpty) return _codecOfCodecs(codecs);
    return _codecOfCodecs(jsonString(format['mimeType']) ?? '');
  }
}
