import 'dart:convert';

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_json.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_room_parser.dart';

/// One URL of a tier, with the container it was read from.
typedef BaiduliveCandidate = ({Uri url, LiveStreamFormat format});

/// One quality candidate: a tier's height, its codec, its container and the
/// URL of it.
typedef BaiduliveEntry = ({int height, LiveStreamCodec? codec, LiveStreamFormat format, Uri url});

/// Baidu Live's streams (3.x's `BaiduLiveApi` media reading): the URL gates,
/// the qualities of a live broadcast and of a recording, the menu order
/// ("优先 H.264", 30-2), the v2 qualities and lines, and the 3.x quality ids.
abstract final class BaidulivePlayParser {
  /// The source quality's id (30-1).
  static const String sourceQualityId = 'source';

  /// The source quality's name (30-1).
  static const String sourceQualityName = '原画';

  /// The suffix of an H.265 quality's name (30-2).
  static const String hevcSuffix = ' · H.265';

  /// The id and name of an ended broadcast's recording when the platform
  /// lists no clarity for it (30-4).
  static const String replayQualityId = 'replay';

  /// See [replayQualityId].
  static const String replayQualityName = '回放';

  /// 3.x's quality ids (`<flv|hls>:<height>:avc`, 0 the source) of the
  /// heights 3.x produced from the recorded answers, and their current ids
  /// (30-1): each 3.x quality is now the lines of one tier. See
  /// [qualityIdFromLegacy].
  static const Map<String, String> legacyQualityIds = {
    'flv:0:avc': sourceQualityId,
    'hls:0:avc': sourceQualityId,
    'flv:1080:avc': '1080p',
    'hls:1080:avc': '1080p',
    'flv:720:avc': '720p',
    'hls:720:avc': '720p',
    'flv:540:avc': '540p',
    'hls:540:avc': '540p',
    'flv:480:avc': '480p',
    'hls:480:avc': '480p',
  };

  static final RegExp _legacyQualityId = RegExp(r'^(?:flv|hls):(\d{1,5}):avc$', caseSensitive: false);

  /// The quality id for a stored one (30-1): 3.x's `<flv|hls>:<height>:avc`
  /// is the tier's id ([sourceQualityId] for height 0, else `<height>p`); a
  /// migration reads a stored quality through this once. Any other id is kept
  /// (trimmed); applying it twice changes nothing.
  static String qualityIdFromLegacy(String id) {
    final value = id.trim();
    final match = _legacyQualityId.firstMatch(value);
    return match == null ? value : _tierId(int.parse(match[1]!));
  }

  static String _tierId(int height) => height == 0 ? sourceQualityId : '${height}p';

  static String _tierName(int height) => height == 0 ? sourceQualityName : '${height}p';

  static bool _primaryHost(String host) =>
      host == 'hls-live.bdstatic.com' || host == 'flv-live.bdstatic.com' || host.endsWith('.liveshow.bdstatic.com');

  static bool _backupHost(String host) => host.endsWith('.liveshow.lss-user.baidubce.com');

  /// [raw] as a live stream URL of room [roomId] in [format] (FLV or HLS), or
  /// null. Accepted:
  /// - the platform's 3.x hosts, `hls-live.bdstatic.com` and
  ///   `*.liveshow.bdstatic.com` as https (http made https, as 3.x did), and
  ///   `flv-live.bdstatic.com` as http (30-9: its https certificate does not
  ///   match the host);
  /// - the platform's current CDN `*.liveshow.lss-user.baidubce.com`, kept as
  ///   given (its https certificate chain does not verify), for the backup
  ///   lines of a tier (30-1);
  ///
  /// on the scheme's default port, without user info or fragment, a `/live/`
  /// path ending in `.flv` or `.m3u8` whose stream names the room (`_<id>`
  /// followed by `-`, `_`, `.`, `/` or the end).
  static Uri? mediaUrl(String raw, {required String roomId, required LiveStreamFormat format}) {
    var uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final primary = _primaryHost(host);
    if (!primary && !_backupHost(host)) return null;
    // A port the scheme does not default to stays and is refused below.
    if (host == 'flv-live.bdstatic.com') {
      if (uri.scheme == 'https' && !uri.hasPort) uri = uri.replace(scheme: 'http');
    } else if (primary && uri.scheme == 'http' && !uri.hasPort) {
      uri = uri.replace(scheme: 'https');
    }
    final extension = format == LiveStreamFormat.hls ? '.m3u8' : '.flv';
    if (!(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(extension) ||
        !RegExp('(?:^|_)${RegExp.escape(roomId)}(?:[-_./]|\$)').hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  /// The stream of a media URL: the file name without its extension, or the
  /// directory of an HLS `playlist.m3u8`; empty when there is none. Empty
  /// segments are dropped first, as the reference does, so `…/a/` still
  /// names the stream `a`.
  static String streamName(Uri url) {
    final List<String> segments;
    try {
      segments = url.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return '';
    }
    if (segments.isEmpty) return '';
    var name = segments.last;
    if (name.toLowerCase() == 'playlist.m3u8' && segments.length > 1) return segments[segments.length - 2];
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }

  /// The qualities of a live room (30-1, 30-2), best first: 原画 (the source)
  /// and one per height (720p, 480p; 1080p and 540p where the room has a
  /// clarity list), each in one codec; an H.265 one is separate and named
  /// with [hevcSuffix].
  ///
  /// The URLs are placed by their stream (the file name): the source is the
  /// stream named `…_<room id>`; a height is the one of the `url_list` or
  /// `url_clarity_list` entry that lists the stream. Read:
  /// - `url_clarity_list[].urls`: `avc_flv`, `flv` (FLV) and `hls` as AVC,
  ///   `hevc_flv` as H.265, at the entry's `resolution`;
  /// - `url_list[].urls[]`: `flv` and `hls` as AVC at the entry's
  ///   `resolution` (the platform's two CDNs);
  /// - `live_flv_url`, `avc_url`, `play_url` (FLV), `live_hls_url` and
  ///   `avc_hls_url` (HLS) as AVC, placed by their stream;
  /// - `live_flv_url_origin` (FLV) and `live_hls_url_origin` (HLS), the
  ///   source, and `hevc_url` (FLV) as the source in H.265.
  ///
  /// The source's codec: AVC when one of the AVC fields names the source
  /// stream; H.265 when the room has no clarity list and the AVC fields name
  /// a transcode instead (the platform then gives an AVC 720p for an H.265
  /// original, 2026-09-29 survey); not known otherwise (null codec).
  ///
  /// A tier's lines: the 3.x hosts first (the lines 3.x played), then the
  /// platform's current CDN as backups (30-1); FLV before HLS within each; a
  /// stream once per host. A URL [mediaUrl] refuses, or whose stream has no
  /// tier, is left out: it costs one line, not the room.
  static List<BaiduliveVariant> liveVariants(Map<String, Object?> video, String roomId) {
    final heights = <String, int>{};
    final sourceName = RegExp('(?:^|_)${RegExp.escape(roomId)}\$');

    Uri? accept(Object? raw, LiveStreamFormat format) =>
        mediaUrl(BaiduliveJson.text(raw), roomId: roomId, format: format);

    final clarity = BaiduliveJson.list(video['url_clarity_list']);
    final listed = <BaiduliveEntry>[];
    for (final value in clarity) {
      final item = BaiduliveJson.object(value);
      final height = BaiduliveJson.positive(item['resolution']);
      if (height == null) continue;
      final urls = BaiduliveJson.object(item['urls']);
      for (final (key, format, codec) in const [
        ('avc_flv', LiveStreamFormat.flv, LiveStreamCodec.avc),
        ('flv', LiveStreamFormat.flv, LiveStreamCodec.avc),
        ('hls', LiveStreamFormat.hls, LiveStreamCodec.avc),
        ('hevc_flv', LiveStreamFormat.flv, LiveStreamCodec.hevc),
      ]) {
        if (accept(urls[key], format) case final url?) {
          listed.add((height: height, codec: codec, format: format, url: url));
        }
      }
    }
    for (final value in BaiduliveJson.list(video['url_list'])) {
      final item = BaiduliveJson.object(value);
      final height = BaiduliveJson.positive(item['resolution']);
      if (height == null) continue;
      for (final pair in BaiduliveJson.list(item['urls'])) {
        final urls = BaiduliveJson.object(pair);
        for (final format in const [LiveStreamFormat.flv, LiveStreamFormat.hls]) {
          if (accept(urls[format.name], format) case final url?) {
            listed.add((height: height, codec: LiveStreamCodec.avc, format: format, url: url));
          }
        }
      }
    }
    for (final entry in listed) {
      if (entry.codec == LiveStreamCodec.avc) heights.putIfAbsent(streamName(entry.url), () => entry.height);
    }

    // The AVC fields, placed by their stream.
    var avcSource = false;
    var avcTranscode = false;
    final named = <BaiduliveEntry>[];
    for (final (key, format) in const [
      ('live_hls_url', LiveStreamFormat.hls),
      ('live_flv_url', LiveStreamFormat.flv),
      ('avc_url', LiveStreamFormat.flv),
      ('play_url', LiveStreamFormat.flv),
      ('avc_hls_url', LiveStreamFormat.hls),
    ]) {
      final url = accept(video[key], format);
      if (url == null) continue;
      final name = streamName(url);
      if (sourceName.hasMatch(name)) {
        avcSource = true;
        named.add((height: 0, codec: LiveStreamCodec.avc, format: format, url: url));
      } else if (heights[name] case final height?) {
        if (key != 'live_hls_url') avcTranscode = true;
        named.add((height: height, codec: LiveStreamCodec.avc, format: format, url: url));
      }
    }
    final sourceCodec = avcSource
        ? LiveStreamCodec.avc
        : clarity.isEmpty && avcTranscode
        ? LiveStreamCodec.hevc
        : null;

    // The source fields.
    for (final (key, format) in const [
      ('live_flv_url_origin', LiveStreamFormat.flv),
      ('live_hls_url_origin', LiveStreamFormat.hls),
    ]) {
      final url = accept(video[key], format);
      if (url == null) continue;
      final name = streamName(url);
      if (sourceName.hasMatch(name)) {
        named.add((height: 0, codec: sourceCodec, format: format, url: url));
      } else if (heights[name] case final height?) {
        named.add((height: height, codec: LiveStreamCodec.avc, format: format, url: url));
      }
    }
    // The explicit H.265 source (`hevc_url`) joins the reads as one more
    // height-0 H.265 entry: when the inferred source codec is H.265 too, it
    // merges into the same `source:hevc` tier (30-2) and the room then has
    // no plain `source` quality at all — the reference's S02-room-hevc case.
    if (accept(video['hevc_url'], LiveStreamFormat.flv) case final url?) {
      named.add((height: 0, codec: LiveStreamCodec.hevc, format: LiveStreamFormat.flv, url: url));
    }

    // 3.x's reading order (clarity, url_list, live_hls_url, live_flv_url,
    // live_flv_url_origin) keeps 3.x's URLs first within a tier.
    final tiers = <String, ({int height, LiveStreamCodec? codec, List<BaiduliveCandidate> urls})>{};
    void add(String id, int height, LiveStreamCodec? codec, BaiduliveCandidate url) {
      final tier = tiers.putIfAbsent(id, () => (height: height, codec: codec, urls: []));
      tier.urls.add(url);
    }

    for (final entry in [...listed, ...named]) {
      final id = '${_tierId(entry.height)}${entry.codec == LiveStreamCodec.hevc ? ':hevc' : ''}';
      add(id, entry.height, entry.codec, (url: entry.url, format: entry.format));
    }
    final variants = [
      for (final MapEntry(key: id, value: tier) in tiers.entries)
        BaiduliveVariant(
          id: id,
          name: '${_tierName(tier.height)}${tier.codec == LiveStreamCodec.hevc ? hevcSuffix : ''}',
          sort: (tier.height == 0 ? 100000 : tier.height) * 10 + _codecRank(tier.codec),
          codec: tier.codec,
          sources: _lineOrder(tier.urls),
        ),
    ]..sort((left, right) => right.sort.compareTo(left.sort));
    return List.unmodifiable(variants);
  }

  static int _codecRank(LiveStreamCodec? codec) => switch (codec) {
    LiveStreamCodec.avc => 2,
    null => 1,
    _ => 0,
  };

  /// [urls] as lines: the 3.x hosts before the current CDN, FLV before HLS,
  /// each stream once per host (the first URL of it).
  static List<BaiduliveSource> _lineOrder(List<BaiduliveCandidate> urls) {
    int group(BaiduliveCandidate entry) =>
        (_primaryHost(entry.url.host.toLowerCase()) ? 0 : 2) + (entry.format == LiveStreamFormat.hls ? 1 : 0);
    final ordered = [
      for (var rank = 0; rank < 4; rank++)
        for (final entry in urls)
          if (group(entry) == rank) entry,
    ];
    final seen = <String>{};
    return [
      for (final entry in ordered)
        if (seen.add('${entry.url.host.toLowerCase()}${entry.url.path}')) (url: entry.url, format: entry.format),
    ];
  }

  /// [value] as a recording of room [roomId] (30-4): an https `.m3u8` on a
  /// `bdstatic.com` host (http made https), on the default port, without user
  /// info or fragment, under the room's stream directory (`_<id>/`); else
  /// null.
  static Uri? replayUrl(Object? value, String roomId) {
    var uri = Uri.tryParse(BaiduliveJson.text(value));
    if (uri == null || !uri.host.toLowerCase().endsWith('.bdstatic.com')) return null;
    if (uri.scheme == 'http' && !uri.hasPort) uri = uri.replace(scheme: 'https');
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        !uri.path.toLowerCase().endsWith('.m3u8') ||
        !uri.path.contains('_$roomId/')) {
      return null;
    }
    return uri;
  }

  static final RegExp _replayKey = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

  /// The qualities of an ended broadcast's recording (30-4), from the first
  /// `replay_list` entry that has one: each `videoInfo.ext.clarityUrl` entry
  /// (H.264, named by its `title`, else its `key`; id `replay:<key>`), or
  /// without them the entry's `video` ([replayQualityId]); then each
  /// `video_hevc` entry (a JSON object of key to URL, H.265, named `<key>`
  /// with [hevcSuffix]; id `replay:<key>:hevc`, 30-2). Only the URLs
  /// [replayUrl] accepts count; each is one HLS line (a recording, not a live
  /// stream).
  static List<BaiduliveVariant> replayVariants(Object? replayList, String roomId) {
    for (final value in BaiduliveJson.list(replayList)) {
      final item = BaiduliveJson.object(value);
      final avc = <({String id, String name, Uri url})>[];
      final seen = <String>{};
      final ext = BaiduliveJson.object(BaiduliveJson.object(item['videoInfo'])['ext']);
      for (final clarity in BaiduliveJson.list(ext['clarityUrl'])) {
        final entry = BaiduliveJson.object(clarity);
        final key = BaiduliveJson.text(entry['key']);
        final url = replayUrl(entry['url'], roomId);
        if (url == null || !_replayKey.hasMatch(key) || !seen.add(key.toLowerCase())) continue;
        avc.add((
          id: '$replayQualityId:${key.toLowerCase()}',
          name: BaiduliveJson.firstText([entry['title'], key]),
          url: url,
        ));
      }
      if (avc.isEmpty) {
        if (replayUrl(item['video'], roomId) case final url?) {
          avc.add((id: replayQualityId, name: replayQualityName, url: url));
        }
      }
      final hevc = <({String id, String name, Uri url})>[];
      final hevcSeen = <String>{};
      for (final MapEntry(key: raw, value: target) in _hevcEntries(item['video_hevc']).entries) {
        final url = replayUrl(target, roomId);
        final name = raw.trim();
        if (url == null || !_replayKey.hasMatch(name) || !hevcSeen.add(name.toLowerCase())) continue;
        hevc.add((id: '$replayQualityId:${name.toLowerCase()}:hevc', name: '$name$hevcSuffix', url: url));
      }
      if (avc.isEmpty && hevc.isEmpty) continue;
      final all = [
        for (final entry in avc) (entry: entry, codec: LiveStreamCodec.avc),
        for (final entry in hevc) (entry: entry, codec: LiveStreamCodec.hevc),
      ];
      return List.unmodifiable([
        for (final (index, candidate) in all.indexed)
          BaiduliveVariant(
            id: candidate.entry.id,
            name: candidate.entry.name,
            sort: (all.length - index) * 10 + _codecRank(candidate.codec),
            codec: candidate.codec,
            sources: [(url: candidate.entry.url, format: LiveStreamFormat.hls)],
          ),
      ]);
    }
    return const [];
  }

  /// A replay entry's `video_hevc`: a JSON object, or the JSON text of one
  /// (the platform sends both); empty when it is neither.
  static Map<String, Object?> _hevcEntries(Object? value) {
    final decoded = value is String ? _hevcJson(value) : value;
    return BaiduliveJson.object(decoded);
  }

  static Object? _hevcJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// [variants] in menu order (30-2): with [preferH264] ("优先 H.264", on by
  /// default) the H.264 qualities first (best first), then those whose codec
  /// is not known, then the H.265 ones, so the default is H.264 and H.265 is
  /// only picked by hand; off, best first (a tier's H.264 before its H.265).
  static List<BaiduliveVariant> ordered(List<BaiduliveVariant> variants, {bool preferH264 = true}) {
    final best = [...variants]..sort((left, right) => right.sort.compareTo(left.sort));
    if (!preferH264) return List.unmodifiable(best);
    return List.unmodifiable([
      for (final rank in const [2, 1, 0])
        for (final variant in best)
          if (_codecRank(variant.codec) == rank) variant,
    ]);
  }

  /// The qualities of [room] (30-1, 30-2, 30-4), in [ordered] order: name, id
  /// and sort of each variant, the platform's rank as `platformOrder`. A room
  /// that cannot be played says why (see [BaiduliveRoom.unavailable]).
  static List<LivePlayQuality> qualities(BaiduliveRoom room, {bool preferH264 = true}) {
    if (room.unavailable case final error?) throw error;
    return List.unmodifiable([
      for (final variant in ordered(room.variants, preferH264: preferH264))
        LivePlayQuality.of(
          label: variant.name,
          qualityId: variant.id,
          platformOrder: variant.sort,
          codec: variant.codec,
        ),
    ]);
  }

  /// The lines of [variant] of room [roomId]: its URLs in order, with the
  /// media headers, the format, the codec (when known) and the host as the
  /// line label (`<host>#2` for a second URL on the same host). The URLs carry
  /// no signature or expiry, so no lease.
  static List<LivePlayLine> lines(BaiduliveVariant variant, String roomId) {
    final headers = BaiduliveEndpoints.mediaHeaders(roomId);
    final hosts = <String, int>{};
    final lines = <LivePlayLine>[];
    for (final source in variant.sources) {
      final host = source.url.host;
      final count = hosts.update(host, (count) => count + 1, ifAbsent: () => 1);
      lines.add(
        LivePlayLine.of(
          url: '${source.url}',
          format: source.format,
          formatSource: LivePlayFormatSource.declared,
          headers: headers,
          codec: variant.codec,
          lineLabel: count == 1 ? host : '$host#$count',
        ),
      );
    }
    return List.unmodifiable(lines);
  }

  /// The lines of [quality] (by its id; a 3.x id is read through
  /// [qualityIdFromLegacy]) in [room], or — when it is null — of the quality
  /// the menu puts first. A quality the room no longer offers is
  /// stream-unavailable, and a room that cannot be played says why.
  static List<LivePlayLine> linesFor(BaiduliveRoom room, LivePlayQuality? quality, {bool preferH264 = true}) {
    if (room.unavailable case final error?) throw error;
    final wanted = qualityIdFromLegacy(quality?.qualityId ?? ordered(room.variants, preferH264: preferH264).first.id);
    final variant = room.variants.where((variant) => variant.id == wanted).firstOrNull;
    if (variant == null) {
      throw BaiduliveFailure(BaiduliveFailureKind.streamUnavailable, 'quality $wanted is not offered');
    }
    return lines(variant, room.roomId);
  }
}
