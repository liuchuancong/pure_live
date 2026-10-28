import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// One quality of a `startPlay` answer: its id (`qualityType`, else
/// `id:<id>`), label, order and one URL per adaptive manifest (CDN).
typedef AcfunQuality = ({String id, String label, int rank, List<String> urls});

/// Pure parsing of AcFun's `startPlay` stream answer: the quality table, the
/// playable lines and the lease of their signatures.
///
/// There is nothing to sign: `startPlay` hands back the signed URLs of every
/// manifest, and each one's own `auth_key` says when it stops working.
abstract final class AcfunPlayParser {
  /// How long before a signed URL's expiry it is renewed.
  static const Duration leaseLead = Duration(minutes: 10);

  /// `videoPlayRes` (a JSON string or an object): the qualities of every
  /// adaptive manifest.
  ///
  /// - hidden representations and URLs that are not plain `http(s)` with a
  ///   host and no user info are left out;
  /// - one quality per id, with the first label it was seen with, the highest
  ///   rank and every URL once, in manifest order;
  /// - the label is the representation's own `name` ("蓝光 8M"), else the
  ///   platform's name for its type, else `画质 <id>`;
  /// - best first by rank, then by id.
  ///
  /// A missing `liveAdaptiveManifest` is api-changed; nothing playable is
  /// stream-unavailable. A representation without an id is left out (the
  /// answer cannot name the quality it offers).
  static List<AcfunQuality> qualities(Object? videoPlayRes) {
    final decoded = videoPlayRes is String ? AcfunJson.tryDecode(videoPlayRes) : videoPlayRes;
    final manifests = AcfunJson.list(AcfunJson.object(decoded)?['liveAdaptiveManifest']);
    if (manifests.isEmpty) throw const AcfunFailure(AcfunFailureKind.apiChanged, 'startPlay: no liveAdaptiveManifest');
    final found = <String, ({String label, int rank, List<String> urls})>{};
    for (final manifest in manifests) {
      final representations = AcfunJson.list(
        AcfunJson.object(AcfunJson.object(manifest)?['adaptationSet'])?['representation'],
      );
      for (final raw in representations) {
        final item = AcfunJson.object(raw);
        if (item == null || item['hidden'] == true) continue;
        final url = AcfunJson.text(item['url']);
        final uri = Uri.tryParse(url);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) continue;
        if (uri.userInfo.isNotEmpty) continue;
        final type = AcfunJson.text(item['qualityType']);
        final number = AcfunJson.intOf(item['id']);
        final id = type.isNotEmpty ? type : (number == null ? '' : 'id:$number');
        if (id.isEmpty) continue;
        final name = AcfunJson.text(item['name']);
        final label = name.isNotEmpty ? name : _labelOf(type, id);
        final rank = qualityRank(level: AcfunJson.intOf(item['level']), bitrate: AcfunJson.intOf(item['bitrate']));
        final previous = found[id];
        found[id] = (
          label: previous?.label ?? label,
          rank: previous == null || rank > previous.rank ? rank : previous.rank,
          urls: [...?previous?.urls, if (!(previous?.urls.contains(url) ?? false)) url],
        );
      }
    }
    if (found.isEmpty) {
      throw const AcfunFailure(AcfunFailureKind.streamUnavailable, 'startPlay: no playable representation');
    }
    final ordered = found.entries.toList()
      ..sort((a, b) {
        final byRank = b.value.rank.compareTo(a.value.rank);
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });
    return [
      for (final MapEntry(:key, :value) in ordered) (id: key, label: value.label, rank: value.rank, urls: value.urls),
    ];
  }

  /// The order of a representation: `level` and `bitrate` are different
  /// scales, so a known level ranks `1000000 + level` (capped) above every
  /// representation that only has a bitrate, which ranks by its bitrate.
  /// Comparing the two directly would put an 8000 kbps representation without
  /// a level above the level-130 source.
  static int qualityRank({int? level, int? bitrate}) {
    if (level != null && level >= 0) return 1000000 + level.clamp(0, 999999);
    return (bitrate ?? 0).clamp(0, 999999);
  }

  /// [qualities] as the shared model, in the answer's order.
  static List<LivePlayQuality> toModel(List<AcfunQuality> qualities) {
    final total = qualities.length;
    return [
      for (final (index, quality) in qualities.indexed)
        LivePlayQuality.of(label: quality.label, qualityId: quality.id, platformOrder: total - index),
    ];
  }

  /// The lines of quality [qualityId] of [qualities] (the answer the room
  /// carries): every URL in answer order with the media headers, FLV or HLS by
  /// path, the CDN host as the line label and the lease of its signature.
  ///
  /// A quality the answer does not have is stream-unavailable: the URLs of
  /// another quality are never swapped in for the one the viewer chose.
  static List<LivePlayLine> lines(
    List<AcfunQuality> qualities, {
    required String qualityId,
    required DateTime issuedAt,
  }) {
    final quality = qualities.where((entry) => entry.id == qualityId).firstOrNull;
    if (quality == null) {
      throw AcfunFailure(AcfunFailureKind.streamUnavailable, 'startPlay: no quality $qualityId');
    }
    final headers = mediaHeaders();
    final hosts = <String, int>{};
    return [
      for (final url in quality.urls)
        if (url.trim() case final text when text.isNotEmpty)
          () {
            final uri = Uri.parse(text);
            final repeat = hosts.update(uri.host, (count) => count + 1, ifAbsent: () => 1);
            return LivePlayLine.of(
              url: text,
              format: uri.path.toLowerCase().endsWith('.m3u8') ? LiveStreamFormat.hls : LiveStreamFormat.flv,
              formatSource: LivePlayFormatSource.inferred,
              headers: headers,
              lineLabel: repeat == 1 ? uri.host : '${uri.host}#$repeat',
              lease: lease(uri, issuedAt),
            );
          }(),
    ];
  }

  /// The lease of a signed media URL: the first `-`-split field of `auth_key`
  /// is its expiry in Unix seconds (about 30 days after issue). Renewed
  /// [leaseLead] before, at most a quarter of the lifetime. Null without a key
  /// or once it has expired — an established connection is not known to be cut
  /// by it.
  static LivePlayLease? lease(Uri url, DateTime issuedAt, {bool allowExpired = false}) {
    final seconds = int.tryParse(url.queryParameters['auth_key']?.split('-').first ?? '');
    if (seconds == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) {
      return allowExpired ? LivePlayLease.of(refreshAt: expiresAt.subtract(leaseLead), expiresAt: expiresAt) : null;
    }
    final quarter = lifetime ~/ 4;
    final lead = quarter < leaseLead ? quarter : leaseLead;
    return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  /// Media request headers: the desktop UA, the live site as Origin and the
  /// live page as Referer. AcFun's CDN checks all three.
  static Map<String, String> mediaHeaders() => const {
    'user-agent': AcfunEndpoints.userAgent,
    'referer': AcfunEndpoints.referer,
    'origin': AcfunEndpoints.origin,
  };

  /// The platform's own name for a quality type, when the answer gives no
  /// `name`.
  static String _labelOf(String type, String id) => switch (type) {
    'STANDARD' => '高清',
    'HIGH' => '超清',
    'SUPER' => '蓝光',
    'BLUE_RAY' => '高码率',
    _ => '画质 $id',
  };
}
