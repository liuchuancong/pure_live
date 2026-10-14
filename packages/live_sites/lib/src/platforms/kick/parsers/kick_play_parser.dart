import 'dart:convert';

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
  /// stream-unavailable: the broadcast ended or its token expired. A body
  /// that is not a playlist is api-changed; a playlist with no usable
  /// variant is stream-unavailable.
  static List<KickVariant> variants(String body, {required Uri master, int status = 200}) {
    if (status == 403 || status == 404) {
      throw KickFailure(KickFailureKind.streamUnavailable, 'master playlist: HTTP $status');
    }
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
    final names = <String, String>{};
    final variants = <String, KickVariant>{};
    Map<String, String>? pending;
    for (final line in lines.skip(1)) {
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final media = _attributes(line.substring('#EXT-X-MEDIA:'.length));
        if (media['TYPE'] == 'VIDEO' && media['GROUP-ID'] != null && media['NAME'] != null) {
          names[media['GROUP-ID']!] = media['NAME']!;
        }
        continue;
      }
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending != null) {
          throw const KickFailure(KickFailureKind.apiChanged, 'master playlist: a variant without a URL');
        }
        pending = _attributes(line.substring('#EXT-X-STREAM-INF:'.length));
        continue;
      }
      if (line.startsWith('#')) continue;
      final attributes = pending;
      pending = null;
      if (attributes == null) continue;
      final url = master.resolve(line);
      final bandwidth = jsonInt(attributes['BANDWIDTH']);
      final size = _resolution.firstMatch(attributes['RESOLUTION'] ?? '');
      if (url.scheme != 'https' || url.host.isEmpty || bandwidth == null || bandwidth <= 0 || size == null) {
        continue;
      }
      final width = int.parse(size.group(1)!);
      final height = int.parse(size.group(2)!);
      final frameRate = jsonDouble(attributes['FRAME-RATE']) ?? 0;
      final name = names[attributes['VIDEO']] ?? '${height}p${frameRate >= 50 ? frameRate.round() : ''}';
      final previous = variants[name];
      if (previous != null && previous.bandwidth >= bandwidth) continue;
      variants[name] = (
        name: name,
        width: width,
        height: height,
        frameRate: frameRate,
        bandwidth: bandwidth,
        codec: videoCodec(attributes['CODECS']),
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

  /// The video codec of an HLS `CODECS` list: [LiveStreamCodec.avc] (`avc1`,
  /// `avc3`), [LiveStreamCodec.hevc] (`hvc1`, `hev1`) or [LiveStreamCodec.av1]
  /// (`av01`); null for none of them.
  static LiveStreamCodec? videoCodec(String? codecs) {
    for (final entry in (codecs ?? '').toLowerCase().split(',')) {
      final name = entry.trim().split('.').first;
      switch (name) {
        case 'avc1' || 'avc3':
          return LiveStreamCodec.avc;
        case 'hvc1' || 'hev1':
          return LiveStreamCodec.hevc;
        case 'av01':
          return LiveStreamCodec.av1;
      }
    }
    return null;
  }

  static final RegExp _resolution = RegExp(r'^([1-9]\d{0,4})x([1-9]\d{0,4})$');

  static final RegExp _attribute = RegExp('([A-Z0-9-]+)=("[^"]*"|[^,]*)');

  /// The attributes of one `#EXT-X-MEDIA` or `#EXT-X-STREAM-INF` line,
  /// quotes stripped.
  static Map<String, String> _attributes(String text) => {
    for (final match in _attribute.allMatches(text))
      match.group(1)!: switch (match.group(2) ?? '') {
        final raw when raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"') => raw.substring(1, raw.length - 1),
        final raw => raw,
      },
  };
}
