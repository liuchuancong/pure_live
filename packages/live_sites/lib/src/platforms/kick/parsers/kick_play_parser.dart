import 'dart:convert';

import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';

/// One variant of the IVS master playlist: the rendition name (`1080p60`,
/// `720p60`, `480p`), its geometry, the codec family its `CODECS` names and
/// the variant playlist URL, resolved against the master.
typedef KickVariant = ({
  String name,
  int width,
  int height,
  double frameRate,
  int bandwidth,
  LiveStreamCodec? codec,
  String url,
});

/// Pure parsing of Kick's playback side: the IVS master playlist a live
/// channel's `playback_url` points at, its qualities and lines, and the
/// playback token's expiry.
///
/// There is no signature to make and no playout map: the channel answer
/// carries one signed HLS master (`.m3u8` on `*.live-video.net`, `?token=<
/// JWT>`), whose `#EXT-X-MEDIA` renditions name the `#EXT-X-STREAM-INF`
/// variants. The variants ride the token's lease: when it expires the master
/// must be re-read, so every line carries it.
abstract final class KickPlayParser {
  /// Weight of the height in a quality's rank, above any bandwidth.
  static const int heightWeight = 1000000000;

  /// The largest master playlist body read.
  static const int responseLimit = 4 * 1024 * 1024;

  /// The variants of the master playlist [body] read from [master], best
  /// first (height, then bandwidth). A refused or gone master (403, 404) is
  /// stream-unavailable: the broadcast ended or its token expired. A 401 is
  /// the edge refusing this client. A body that is not a playlist, or one
  /// whose last `#EXT-X-STREAM-INF` has no URL under it, is api-changed; a
  /// playlist with no usable variant is stream-unavailable.
  static List<KickVariant> variants(String body, {required Uri master, int status = 200}) {
    if (status == 403 || status == 404) {
      throw KickFailure(KickFailureKind.streamUnavailable, 'master playlist: HTTP $status');
    }
    if (status == 401) throw const KickFailure(KickFailureKind.riskControl, 'master playlist: HTTP 401');
    if (status >= 500) throw KickFailure(KickFailureKind.network, 'master playlist: HTTP $status');
    if (status == 429) throw const KickFailure(KickFailureKind.rateLimited, 'master playlist: HTTP 429');
    if (status < 200 || status >= 300) {
      throw KickFailure(KickFailureKind.apiChanged, 'master playlist: HTTP $status (${jsonSnippet(body)})');
    }
    if (body.length > responseLimit) {
      throw const KickFailure(KickFailureKind.apiChanged, 'master playlist: too large');
    }
    final lines = const LineSplitter().convert(body).map((line) => line.trim()).toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') {
      throw KickFailure(KickFailureKind.apiChanged, 'master playlist: not a playlist (${jsonSnippet(body)})');
    }
    var pending = false;
    for (final line in lines.skip(1)) {
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending) {
          throw const KickFailure(KickFailureKind.apiChanged, 'master playlist: a variant without a URL');
        }
        pending = true;
        continue;
      }
      if (line.startsWith('#')) continue;
      pending = false;
    }
    if (pending) {
      throw const KickFailure(KickFailureKind.apiChanged, 'master playlist: a variant without a URL');
    }
    // The master is read through the shared HLS parser; a body that is not a
    // master playlist (or that the parser refuses) yields no variants and falls
    // to the stream-unavailable answer below, exactly as before. Relative
    // variant URIs are resolved against the master here rather than through the
    // parser so no part of the master's own `?token=` is copied onto a variant.
    final parsed = parseHlsMaster(body, masterUrl: master);
    final names = <String, String>{
      for (final rendition in parsed?.master.renditions ?? const <HlsRendition>[])
        if (rendition.type == HlsMediaType.video) rendition.groupId: rendition.name,
    };
    final variants = <String, KickVariant>{};
    for (final entry in parsed?.master.variants ?? const <HlsVariant>[]) {
      final url = resolveHlsVariantUri(entry.uri, master: master);
      final bandwidth = entry.bandwidth;
      final width = entry.width;
      final height = entry.height;
      if (!url.isScheme('https') ||
          url.host.isEmpty ||
          bandwidth <= 0 ||
          width == null ||
          width <= 0 ||
          height == null ||
          height <= 0) {
        continue;
      }
      final frameRate = entry.frameRate ?? 0;
      final name = names[entry.videoGroupId] ?? '${height}p${frameRate >= 50 ? frameRate.round() : ''}';
      final previous = variants[name];
      if (previous != null && previous.bandwidth >= bandwidth) continue;
      variants[name] = (
        name: name,
        width: width,
        height: height,
        frameRate: frameRate,
        bandwidth: bandwidth,
        codec: hlsVideoCodecOf(entry.codecs),
        url: '$url',
      );
    }
    if (variants.isEmpty) {
      throw KickFailure(KickFailureKind.streamUnavailable, 'master playlist: no variant (${jsonSnippet(body)})');
    }
    final result = variants.values.toList()
      ..sort((a, b) {
        final sortA = a.height * heightWeight + a.bandwidth;
        final sortB = b.height * heightWeight + b.bandwidth;
        return sortB.compareTo(sortA);
      });
    return result;
  }

  /// The qualities of [variants], best first: the rendition name is both the
  /// label and the id, so a recovered master selects the same one.
  static List<LivePlayQuality> qualities(List<KickVariant> variants) {
    final total = variants.length;
    return [
      for (final (index, variant) in variants.indexed)
        LivePlayQuality(
          label: variant.name,
          qualityId: variant.name,
          codec: variant.codec,
          platformOrder: total - index,
        ),
    ];
  }

  /// The playable lines of [variant]: its variant playlist with the media
  /// headers of channel [slug], HLS as the master declares, its codec, the
  /// declared geometry and the master token's [expiresAt] as the lease (the
  /// variant outlives nothing here: a new token comes with a new master).
  static List<LivePlayLine> lines(
    KickVariant variant, {
    required String slug,
    required Uri master,
    DateTime? expiresAt,
    DateTime? now,
  }) => [
    LivePlayLine(
      url: variant.url,
      format: LiveStreamFormat.hls,
      formatSource: LivePlayFormatSource.declared,
      headers: KickEndpoints.mediaHeaders(slug),
      codec: variant.codec,
      lineLabel: master.host,
      lease: lease(expiresAt: expiresAt, now: now ?? DateTime.now().toUtc()),
      geometry: PlayGeometry(
        width: variant.width,
        height: variant.height,
        frameRate: variant.frameRate >= 1 ? variant.frameRate.round() : null,
        bitrateKbps: variant.bandwidth ~/ 1000,
      ),
    ),
  ];

  /// The variant [qualityId] names in [variants] (the rendition name), else
  /// the best one ([fallback], null = none when the id names nothing).
  static KickVariant? pick(List<KickVariant> variants, String? qualityId, {bool fallback = true}) {
    final id = qualityId?.trim() ?? '';
    if (id.isEmpty) return variants.firstOrNull;
    return variants.where((variant) => variant.name == id).firstOrNull ?? (fallback ? variants.firstOrNull : null);
  }

  /// The lease of a playback token that dies at [expiresAt]: refresh one
  /// minute early (never in the past), and the URL is certain to fail at the
  /// expiry itself. Null when the token names no expiry.
  static LivePlayLease? lease({required DateTime now, DateTime? expiresAt}) {
    if (expiresAt == null) return null;
    final refresh = expiresAt.subtract(const Duration(minutes: 1));
    return LivePlayLease(refreshAt: refresh.isAfter(now) ? refresh : expiresAt, expiresAt: expiresAt);
  }

  /// When the playback token of [master] expires: its JWT payload's `exp`,
  /// or null when it has none.
  static DateTime? tokenExpiry(Uri master) {
    final parts = (master.queryParameters['token'] ?? '').split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? jsonInt(payload['exp']) : null;
      return exp == null || exp <= 0 || exp > 8640000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } on FormatException {
      return null;
    }
  }

  /// The video codec of an HLS `CODECS` list: delegates to [hlsVideoCodecOf].
  static LiveStreamCodec? videoCodec(String? codecs) => hlsVideoCodecOf(codecs);
}
