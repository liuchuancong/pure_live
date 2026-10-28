import 'dart:convert';

import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';

/// One variant of a CHZZK master playlist, before it is grouped into a
/// quality: the media (line) id it came from, the variant address, its height,
/// frame rate and bandwidth, the codec the playlist names and the lease of its
/// Akamai token.
typedef ChzzkVariant = ({
  String mediaId,
  String url,
  int height,
  double frameRate,
  int bandwidth,
  LiveStreamCodec? codec,
  LivePlayLease? lease,
});

/// Pure parsing of CHZZK's playback side: the `livePlaybackJson` of a live
/// detail, the master playlists it points at, and the qualities and lines they
/// hold.
///
/// There is no signature to make: the platform hands back Akamai-tokened
/// addresses (`hdnts` on the master, `hdntl` inside the variant path) and this
/// adapter only reads their `exp` to know when to re-resolve. A master is asked
/// with the API headers; its segments are played with the media headers.
abstract final class ChzzkPlayParser {
  /// The HLS masters of `livePlaybackJson`: the `HLS` and `LLHLS` items of
  /// protocol `HLS`, in its order, each master once. An absent field is no
  /// master at all (a live with nothing to play). A value that is not a JSON
  /// string, an answer with no `media` list or more than
  /// [ChzzkEndpoints.maxMediaItems] items is api-changed; an item without a
  /// protocol or id, or whose master is not a plain https address on the Akamai
  /// CDN, is skipped — only when nothing usable is left is it api-changed, so
  /// one odd item cannot hide an otherwise playable live.
  static List<ChzzkMedia> media(Object? raw) {
    const what = 'livePlaybackJson';
    if (raw == null || raw == '') return const [];
    if (raw is! String || raw.length > ChzzkEndpoints.responseLimit) {
      throw const ChzzkFailure(ChzzkFailureKind.apiChanged, 'livePlaybackJson: not a JSON string');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const ChzzkFailure(ChzzkFailureKind.apiChanged, 'livePlaybackJson: not JSON');
    }
    final items = list(object(decoded, what)['media'], '$what.media');
    if (items.length > ChzzkEndpoints.maxMediaItems) {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: ${items.length} media');
    }
    final result = <ChzzkMedia>[];
    final seen = <Uri>{};
    var broken = 0;
    for (final item in items) {
      if (item is! Map) {
        broken++;
        continue;
      }
      final protocol = text(item['protocol']);
      final id = text(item['mediaId']);
      if (protocol.isEmpty || id.isEmpty) {
        broken++;
        continue;
      }
      if (protocol != 'HLS' || (id != 'HLS' && id != 'LLHLS')) continue;
      final url = _mediaUrl(item['path']);
      if (url == null) {
        broken++;
        continue;
      }
      if (seen.add(url)) result.add(ChzzkMedia(id, url));
    }
    if (result.isEmpty && broken > 0) {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: $broken unusable media, no usable master');
    }
    return List.unmodifiable(result);
  }

  /// A master address the adapter may ask: a non-empty https URL of at most
  /// [ChzzkEndpoints.maxPathLength] characters, without whitespace or control
  /// characters, user info or fragment, on `akamaized.net` or a subdomain of it.
  static Uri? _mediaUrl(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > ChzzkEndpoints.maxPathLength ||
        value.contains(RegExp(r'[\s\x00-\x1f]'))) {
      return null;
    }
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'akamaized.net' || host.endsWith('.akamaized.net'))) {
      return null;
    }
    return uri;
  }

  /// A master playlist answer: its text, or the failure. The master is part of
  /// the live, so a 404 means the stream is gone (not that the room is missing).
  static String master(String body, {required String what, int status = 200}) {
    if (status == 404) throw ChzzkFailure(ChzzkFailureKind.streamUnavailable, '$what: HTTP 404');
    if (statusFailure(status, what) case final failure?) throw failure;
    if (body.length > ChzzkEndpoints.responseLimit) {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '$what: answer over ${ChzzkEndpoints.responseLimit} characters');
    }
    return body;
  }

  /// The variants of one master: every `#EXT-X-STREAM-INF` with the URI after
  /// it, resolved against [master]. A variant without a resolution (the audio
  /// only track, which the reference failed the whole live on) is left out; a
  /// body that is not a playlist at all is api-changed, and a playlist with no
  /// usable variant is stream-unavailable.
  static List<ChzzkVariant> variants(String playlist, {required ChzzkMedia media, required DateTime issuedAt}) {
    final lines = playlist.split('\n');
    if (lines.first.trim().trimLeft() != '#EXTM3U') {
      throw ChzzkFailure(ChzzkFailureKind.apiChanged, '${media.id} master: not a playlist');
    }
    // The master is read through the shared HLS parser; a body that is not a
    // master playlist yields no variants and falls to the stream-unavailable
    // answer below. Relative URIs are resolved against the master here so an
    // absolute variant keeps its own `hdntl` path token and a relative one
    // never inherits the master's `hdnts` query.
    final result = parseHlsMaster(playlist, masterUrl: media.url);
    final variants = <ChzzkVariant>[];
    for (final parsed in result?.master.variants ?? const <HlsVariant>[]) {
      final uri = resolveHlsVariantUri(parsed.uri, master: media.url);
      // A variant URI that is not http(s) is left out (the master itself is
      // always https on the CDN; a stray scheme cannot be played).
      if (!uri.isScheme('http') && !uri.isScheme('https')) continue;
      final height = parsed.height ?? 0;
      if (height <= 0) continue;
      variants.add((
        mediaId: media.id,
        url: uri.toString(),
        height: height,
        frameRate: parsed.frameRate ?? 0,
        bandwidth: parsed.bandwidth,
        codec: hlsVideoCodecOf(parsed.codecs),
        lease: lease(uri, master: media.url, issuedAt: issuedAt),
      ));
    }
    if (variants.isEmpty) {
      throw ChzzkFailure(ChzzkFailureKind.streamUnavailable, '${media.id} master: no video variant');
    }
    return variants;
  }

  /// The qualities of the [variants] read together, best first: one per
  /// `<height>p`, plus `60` at 50 fps or more, labelled `<id> · HLS`, ranked
  /// by height and then by the bandwidth of their fastest variant. Every quality
  /// is served by both masters, `HLS` listed before `LLHLS`, so a viewer may
  /// take the latency it wants within the quality it asked for.
  static List<LivePlayQuality> qualities(List<ChzzkVariant> variants) {
    final byQuality = <String, List<ChzzkVariant>>{};
    final rank = <String, int>{};
    for (final variant in variants) {
      final id = _qualityId(variant);
      byQuality.putIfAbsent(id, () => []).add(variant);
      final best = variant.height * 10000000 + variant.bandwidth;
      if ((rank[id] ?? 0) < best) rank[id] = best;
    }
    if (byQuality.isEmpty) {
      throw const ChzzkFailure(ChzzkFailureKind.streamUnavailable, 'no video variant');
    }
    final ids = byQuality.keys.toList()..sort((a, b) => (rank[b] ?? 0).compareTo(rank[a] ?? 0));
    final total = ids.length;
    return [
      for (var index = 0; index < total; index++)
        LivePlayQuality.of(
          label: '${ids[index]} · HLS',
          qualityId: ids[index],
          platformOrder: total - index,
          codec: byQuality[ids[index]]!.first.codec,
        ),
    ];
  }

  /// The lines of [quality] (its id) among the [variants], deduplicated by URL
  /// and in the masters' order; the quality's own lines when [quality] is null.
  static List<LivePlayLine> lines(List<ChzzkVariant> variants, {String? quality}) {
    final wanted = quality?.trim();
    final urls = <String>{};
    return [
      for (final variant in variants)
        if (wanted == null || wanted.isEmpty || _qualityId(variant) == wanted)
          if (urls.add(variant.url))
            LivePlayLine.of(
              url: variant.url,
              format: LiveStreamFormat.hls,
              formatSource: LivePlayFormatSource.declared,
              headers: ChzzkEndpoints.mediaHeaders,
              codec: variant.codec,
              lineLabel: variant.mediaId,
              lease: variant.lease,
              geometry: PlayGeometry.of(
                height: variant.height > 0 ? variant.height : null,
                frameRate: variant.frameRate >= 1 ? variant.frameRate.round() : null,
                bitrateKbps: variant.bandwidth > 0 ? variant.bandwidth ~/ 1000 : null,
              ),
            ),
    ];
  }

  /// The quality a variant belongs to: `<height>p`, plus `60` at 50 fps or
  /// more.
  static String _qualityId(ChzzkVariant variant) => '${variant.height}p${variant.frameRate >= 50 ? '60' : ''}';

  /// The video codec of a `CODECS` list: delegates to [hlsVideoCodecOf].
  static LiveStreamCodec? codecOf(String? codecs) => hlsVideoCodecOf(codecs);

  static final RegExp _variantExpiry = RegExp(r'hdntl=exp=(\d{9,12})');
  static final RegExp _masterExpiry = RegExp(r'(?:^|~)exp=(\d{9,12})');

  /// When the token of [master] (its `hdnts`'s `exp`) expires; null without one.
  static DateTime? masterExpiry(Uri master) {
    String? exp;
    try {
      exp = _masterExpiry.firstMatch(master.queryParameters['hdnts'] ?? '')?.group(1);
    } on FormatException {
      exp = null;
    }
    return exp == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(exp) * 1000, isUtc: true);
  }

  /// The lease of a variant issued at [issuedAt]: its Akamai token expires at
  /// the `exp` of the variant's `hdntl` — a path element of a LLHLS manifest,
  /// or the query of a plain HLS one — else of the master's `hdnts`
  /// (about 17 hours after issue in the capture of 2026-09-27), and it is
  /// renewed [ChzzkEndpoints.leaseLead] before — at most a quarter of its
  /// lifetime. Every HLS segment is a new request, so an expired token ends
  /// playback rather than merely the next playlist read
  /// ([LivePlayLease.requiresReconnect]). Null without a future expiry.
  static LivePlayLease? lease(Uri variant, {required Uri master, required DateTime issuedAt}) {
    final exp = _variantExpiry.firstMatch(variant.path)?.group(1) ?? _variantExpiry.firstMatch(variant.query)?.group(1);
    final expiresAt = exp == null
        ? masterExpiry(master)
        : DateTime.fromMillisecondsSinceEpoch(int.parse(exp) * 1000, isUtc: true);
    if (expiresAt == null) return null;
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) return null;
    final lead = Duration(microseconds: _min(ChzzkEndpoints.leaseLead.inMicroseconds, lifetime.inMicroseconds ~/ 4));
    return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt, requiresReconnect: true);
  }

  static int _min(int a, int b) => a < b ? a : b;

  /// Whether these lines can still be handed out at [now]: no lease is due.
  static bool linesFresh(List<LivePlayLine> lines, DateTime now) {
    for (final line in lines) {
      if (line.lease case final lease? when !now.isBefore(lease.refreshAt)) return false;
    }
    return true;
  }

  /// Whether these masters can still be requested at [now]: none of their
  /// tokens expires within [ChzzkEndpoints.leaseLead]. A master that names no
  /// expiry is treated as fresh, as the reference does.
  static bool mastersFresh(List<ChzzkMedia> media, DateTime now) => media.every(
    (item) => switch (masterExpiry(item.url)) {
      final expiry? => now.add(ChzzkEndpoints.leaseLead).isBefore(expiry),
      null => true,
    },
  );
}
