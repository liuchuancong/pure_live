import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_json.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';

/// The pull URLs of one live, split the way this contract asks for them: the
/// qualities best first, and the lines behind each quality id.
typedef SeventeenLiveStreams = ({List<LivePlayQuality> qualities, Map<String, List<LivePlayLine>> lines});

/// Pure parsing of 17LIVE's playback side: the `pullURLsInfo` of a `lives/<id>`
/// answer, the pull addresses it names, and the qualities and lines they hold.
///
/// There is no signature to make and no lease to keep: the pull URLs are
/// unsigned and do not expire, so a line carries no lease and a player that
/// reopens one is not punished — only recovery re-reads the room, because the
/// answer names the CDN that serves now (REG-17LIVE-002).
abstract final class SeventeenLivePlayParser {
  /// The quality id for [id] as the reference stored it
  /// ([SeventeenLiveEndpoints.legacyQualityIds], any case): `standard` is
  /// 原画; any other id is kept, trimmed.
  static String qualityIdFromLegacy(String id) =>
      SeventeenLiveEndpoints.legacyQualityIds[id.trim().toLowerCase()] ?? id.trim();

  /// The qualities of a live `lives/<id>` answer: the providers of
  /// `pullURLsInfo.rtmpURLs` (else `rtmpUrls`), in their order — only the first
  /// one serves at a time (REG-17LIVE-002) — and for each quality of
  /// [SeventeenLiveEndpoints.qualityFields], best first, every field of every
  /// provider that is a pull URL ([pullUrl]) is a line, each URL once. Named
  /// `<name> · FLV`, ranked by [SeventeenLiveEndpoints.qualitySorts] (a bigger
  /// `platformOrder` is the better quality, as on bilibili). Each line carries
  /// the media headers, the FLV format, its CDN (`tencent`, `wansu`) and, for the
  /// H.264 transcode, the AVC codec — the other qualities follow the
  /// broadcaster's encoder and may be HEVC (REG-17LIVE-001).
  ///
  /// A provider that is not an object, a URL field that is not text, providers
  /// beyond [SeventeenLiveEndpoints.maxProviders] and providers that are not a
  /// list only lose themselves; each is noted in [skipped]. Empty when nothing
  /// is offered.
  ///
  /// The H.264 transcode is offered only when the first CDN (the one serving) is
  /// not one of [SeventeenLiveEndpoints.untranscodedCdns], and never read from
  /// one of them (E03.18): listing it from every CDN left "优先 H.264" opening a
  /// Wansu room on a quality nothing serves.
  static SeventeenLiveStreams streams(Map<String, dynamic> data, {required String roomId, List<String>? skipped}) {
    void skip(String reason) => skipped?.add(reason);
    Object? providers;
    final pull = data['pullURLsInfo'];
    if (pull is Map) providers = pull['rtmpURLs'];
    providers ??= data['rtmpUrls'];
    if (providers == null) return (qualities: const [], lines: const {});
    if (providers is! List) {
      skip('rtmpURLs is not a list');
      return (qualities: const [], lines: const {});
    }
    if (providers.length > SeventeenLiveEndpoints.maxProviders) {
      skip('${providers.length - SeventeenLiveEndpoints.maxProviders} providers over '
          '${SeventeenLiveEndpoints.maxProviders}');
    }
    final lines = <String, List<LivePlayLine>>{};
    final headers = SeventeenLiveEndpoints.mediaHeaders(roomId);
    String? firstCdn;
    for (final (index, item) in providers.take(SeventeenLiveEndpoints.maxProviders).indexed) {
      final provider = optionalObject(item);
      if (provider == null) {
        skip('provider $index is not an object');
        continue;
      }
      for (final MapEntry(key: id, value: fields) in SeventeenLiveEndpoints.qualityFields.entries) {
        for (final field in fields) {
          final value = provider[field];
          if (value == null || value == '') continue;
          if (value is! String) {
            skip('provider $index: $field is not text');
            continue;
          }
          final url = pullUrl(value);
          if (url == null) continue;
          final cdn = url.host.toLowerCase().split('-').first;
          firstCdn ??= cdn;
          if (id == SeventeenLiveEndpoints.h264QualityId && SeventeenLiveEndpoints.untranscodedCdns.contains(cdn)) {
            continue;
          }
          final bucket = lines.putIfAbsent(id, () => []);
          final address = url.toString();
          if (bucket.any((line) => line.url == address)) continue;
          bucket.add(
            LivePlayLine(
              url: address,
              format: LiveStreamFormat.flv,
              formatSource: LivePlayFormatSource.declared,
              headers: headers,
              codec: id == SeventeenLiveEndpoints.h264QualityId ? LiveStreamCodec.avc : null,
              lineLabel: cdn,
            ),
          );
        }
      }
    }
    if (SeventeenLiveEndpoints.untranscodedCdns.contains(firstCdn)) lines.remove(SeventeenLiveEndpoints.h264QualityId);
    return (
      qualities: List.unmodifiable([
        for (final id in SeventeenLiveEndpoints.qualityFields.keys)
          if (lines.containsKey(id))
            LivePlayQuality(
              label: '${SeventeenLiveEndpoints.qualityNames[id]} · FLV',
              qualityId: id,
              platformOrder: SeventeenLiveEndpoints.qualitySorts[id]!,
              codec: id == SeventeenLiveEndpoints.h264QualityId ? LiveStreamCodec.avc : null,
            ),
      ]),
      lines: Map.unmodifiable(lines),
    );
  }

  /// A pull URL as the platform serves one: http(s) on a `*.17app.co` host
  /// containing `pull-rtmp`, an `.flv` path, without whitespace, user info or
  /// fragment. Always https — the Tencent CDN serves https too — except an http
  /// URL with an explicit port other than 80, kept as given since its https port
  /// is unknown. Null otherwise.
  static Uri? pullUrl(String raw) {
    if (raw.isEmpty || raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) return null;
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !host.endsWith('.17app.co') ||
        !host.contains('pull-rtmp') ||
        !uri.path.toLowerCase().endsWith('.flv')) {
      return null;
    }
    if (uri.scheme == 'https' || (uri.hasPort && uri.port != 80)) return uri;
    return Uri(scheme: 'https', host: uri.host, path: uri.path, query: uri.hasQuery ? uri.query : null);
  }

  /// [data]'s qualities in the order shown. With [preferH264] ("优先 H.264", on
  /// by default) the H.264 transcode comes first, so it is the default (the
  /// others may be HEVC: REG-17LIVE-001), then 原画 and the rest best first; off,
  /// best first (原画, enhanced, HD, H.264). A room with nothing to play throws
  /// why.
  static List<LivePlayQuality> playQualities(SeventeenLiveRoomData data, {bool preferH264 = true}) {
    final offered = data.qualities;
    if (offered.isEmpty) {
      throw data.unavailable ??
          const SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, 'the room offers no quality');
    }
    if (!preferH264) return offered;
    return List.unmodifiable([
      ...offered.where((quality) => quality.qualityId == SeventeenLiveEndpoints.h264QualityId),
      ...offered.where((quality) => quality.qualityId != SeventeenLiveEndpoints.h264QualityId),
    ]);
  }

  /// The lines of [quality] (by its id; the reference's `standard` id is read
  /// through [qualityIdFromLegacy]) — the default quality of
  /// [playQualities] when it is null or blank. A quality the room does not offer
  /// throws [SeventeenLiveFailureKind.streamUnavailable], and a room with nothing
  /// to play reports why.
  static List<LivePlayLine> lines(SeventeenLiveRoomData data, {String? quality, bool preferH264 = true}) {
    final wanted = quality?.trim();
    final id = wanted == null || wanted.isEmpty
        ? playQualities(data, preferH264: preferH264).first.qualityId!
        : qualityIdFromLegacy(wanted);
    final offered = data.lines[id];
    if (offered == null) {
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, 'quality $id is not offered');
    }
    return offered;
  }
}
