import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_json.dart';

/// One quality of a master playlist before it is ranked: the label, the id it
/// merges under (`height:fps:bandwidth:VIDEO-group`), the sort key (source
/// above bandwidth), the variant URLs (a quality may be served by several
/// hosts) and the codec the playlist names.
typedef TwitchVariantGroup = ({
  String label,
  String qualityId,
  int sort,
  String group,
  List<String> urls,
  LiveStreamCodec? codec,
});

/// Pure parsing of Twitch's playback side: usher's error answers and its HLS
/// master playlist.
///
/// There is no signature to make: `PlaybackAccessToken` hands back a server-
/// minted `value` and `signature`, which usher receives as `token` and `sig`.
/// The variant URLs it then lists are long-lived — they outlive the 20-minute
/// access token — so they carry no lease; recovery asks for a fresh playlist.
abstract final class TwitchPlayParser {
  /// The usher answer: 404 is a channel that is not broadcasting; 403 names
  /// why this viewer may not watch (`geo` is region-blocked, another reason
  /// needs a login); 429 is rate-limited and 5xx network; anything else is
  /// api-changed. An answer asking for a browser integrity token
  /// (`extensions.challenge`, or an error naming a failed integrity check) is
  /// risk control whatever its status. The body is `[{error_code, error}]`.
  static void usherStatus(int status, String body) {
    if (status >= 200 && status < 300) return;
    if (status >= 500) throw TwitchFailure(TwitchFailureKind.network, 'usher: HTTP $status');
    if (status == 429) throw const TwitchFailure(TwitchFailureKind.rateLimited, 'usher: HTTP 429');
    final decoded = TwitchJson.tryDecode(body);
    final first = TwitchJson.object(decoded is List && decoded.isNotEmpty ? decoded.first : decoded);
    final code = TwitchJson.stringOf(first?['error_code']) ?? '';
    final message = TwitchJson.stringOf(first?['error']) ?? '';
    final detail = 'usher: HTTP $status $code $message'.trim();
    if (TwitchJson.isIntegrityRejection(decoded) ||
        ['failed integrity check', 'integrity token'].any((phrase) => message.toLowerCase().contains(phrase))) {
      throw TwitchFailure(TwitchFailureKind.riskControl, detail);
    }
    if (status == 404) throw TwitchFailure(TwitchFailureKind.streamUnavailable, detail);
    if (status == 403) {
      if ('$code $message'.toLowerCase().contains('geo')) {
        throw TwitchFailure(TwitchFailureKind.regionBlocked, detail);
      }
      throw TwitchFailure(TwitchFailureKind.needsLogin, detail);
    }
    throw TwitchFailure(TwitchFailureKind.apiChanged, detail);
  }

  /// The master playlist: every `#EXT-X-STREAM-INF` with the URI after it,
  /// grouped by height, frame rate, bandwidth and `VIDEO` group — the
  /// broadcaster's own stream (`chunked`) first, the rest by bandwidth.
  ///
  /// A body that is not a playlist is api-changed; a playlist with no variant
  /// is stream-unavailable. A variant URI that is not `http(s)` is skipped.
  static List<TwitchVariantGroup> groups(String playlist, {required Uri master}) {
    if (!playlist.trimLeft().startsWith('#EXTM3U')) {
      throw TwitchFailure(TwitchFailureKind.apiChanged, 'usher: not a playlist (${TwitchJson.snippet(playlist)})');
    }
    // The master is read through the shared HLS parser; a body that is not a
    // master playlist yields no variants and falls to the stream-unavailable
    // answer below. Relative URIs are resolved against the master here so no
    // part of the master's own query is copied onto a variant.
    final result = parseHlsMaster(playlist, masterUrl: master);
    final grouped = <String, TwitchVariantGroup>{};
    for (final variant in result?.master.variants ?? const <HlsVariant>[]) {
      final resolved = resolveHlsVariantUri(variant.uri, master: master);
      if (!resolved.isScheme('http') && !resolved.isScheme('https')) continue;
      final bandwidth = variant.bandwidth;
      final height = variant.height ?? 0;
      final frameRate = variant.frameRate ?? 0;
      final group = (variant.videoGroupId ?? '').toLowerCase();
      final source = group == 'chunked';
      final id = '$height:${frameRate.round()}:$bandwidth:$group';
      final url = resolved.toString();
      if (grouped[id] case final existing?) {
        if (!existing.urls.contains(url)) existing.urls.add(url);
        continue;
      }
      grouped[id] = (
        label: qualityName(bandwidth, height: height, frameRate: frameRate, source: source),
        qualityId: id,
        sort: source ? 1 << 30 : bandwidth,
        group: group,
        urls: [url],
        codec: hlsVideoCodecOf(variant.codecs),
      );
    }
    if (grouped.isEmpty) throw const TwitchFailure(TwitchFailureKind.streamUnavailable, 'usher: no variant');
    return [...grouped.values]..sort((a, b) => b.sort.compareTo(a.sort));
  }

  /// The qualities of a playlist, best first.
  static List<LivePlayQuality> qualities(List<TwitchVariantGroup> groups) {
    final total = groups.length;
    return [
      for (final (index, group) in groups.indexed)
        LivePlayQuality(
          label: group.label,
          qualityId: group.qualityId,
          codec: group.codec,
          platformOrder: total - index,
        ),
    ];
  }

  /// The playable lines of [group] for room [roomId] (HLS, one line per
  /// variant host, with the media headers).
  static List<LivePlayLine> lines(TwitchVariantGroup group, {required String roomId}) {
    final headers = mediaHeaders(roomId);
    return [
      for (final url in group.urls.where((url) => url.trim().isNotEmpty))
        LivePlayLine(
          url: url.trim(),
          format: LiveStreamFormat.hls,
          formatSource: LivePlayFormatSource.declared,
          headers: headers,
          codec: group.codec,
          lineLabel: Uri.tryParse(url.trim())?.host,
        ),
    ];
  }

  /// The group [qualityId] names in [groups]: the same id, else the same
  /// `VIDEO` group (an id's bandwidth moves between playlists), else the same
  /// label; null when none is (the caller then takes the best).
  static TwitchVariantGroup? sameGroup(List<TwitchVariantGroup> groups, String? qualityId, {String label = ''}) {
    final id = qualityId?.trim() ?? '';
    String groupOf(Object? value) => '$value'.split(':').last;
    return groups.where((group) => group.qualityId == id).firstOrNull ??
        (id.contains(':') ? groups.where((group) => group.group == groupOf(id)).firstOrNull : null) ??
        (label.isEmpty ? null : groups.where((group) => group.label == label).firstOrNull);
  }

  /// The video codec of an HLS `CODECS` list: delegates to [hlsVideoCodecOf].
  static LiveStreamCodec? videoCodec(String codecs) => hlsVideoCodecOf(codecs);

  /// The quality label: `<height>p[<fps>][（原画）]` (the frame rate named
  /// from 45 fps up, the broadcaster's own stream marked 原画), or, when the
  /// playlist gives no resolution, a label from the bandwidth.
  static String qualityName(int bandwidth, {required int height, required double frameRate, required bool source}) {
    if (height > 0) {
      final fps = frameRate >= 45 ? '${frameRate.round()}' : '';
      return '${height}p$fps${source ? '（原画）' : ''}';
    }
    if (source) return '原画';
    if (bandwidth > 5000000) return '1080P';
    if (bandwidth > 2500000) return '720P';
    if (bandwidth > 1000000) return '480P';
    if (bandwidth > 500000) return '360P';
    return '自动';
  }

  /// Media request headers for [roomId]: the desktop UA, the site origin and
  /// the channel page as Referer. The login cookie is deliberately not sent
  /// to the CDN.
  static Map<String, String> mediaHeaders(String roomId) {
    final id = roomId.trim();
    return {
      'user-agent': TwitchEndpoints.userAgent,
      'origin': TwitchEndpoints.origin,
      'referer': id.isEmpty ? '${TwitchEndpoints.origin}/' : TwitchEndpoints.roomPageUrl(id),
    };
  }
}
