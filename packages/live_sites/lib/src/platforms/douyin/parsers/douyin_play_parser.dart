import 'dart:math' as math;

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_json.dart';

/// One media URL of a quality, with the format the platform listed it under.
typedef _Line = ({Uri url, LiveStreamFormat format});

/// One quality before its platform order is stamped on it: the label, the
/// lines it offers, its codec, the picture size the platform declares for it
/// and the rank it was sorted by.
typedef _Variant = ({
  LivePlayQuality quality,
  List<_Line> lines,
  LiveStreamCodec? codec,
  ({int width, int height})? size,
  int rank,
});

/// The ranked qualities of a `stream_url`, with the sdk keys that are only
/// aliases of a kept one (identical URLs).
typedef _Variants = ({List<_Variant> list, Map<String, String> aliases});

/// Pure parsing of Douyin's web play path: the room's `stream_url` is the
/// whole answer (no app-style play request and no signature), so qualities
/// and lines are assembled from it, each line carrying the media headers, the
/// declared format and codec, the picture size and a lease read off the URL's
/// own expiry.
abstract final class DouyinPlayParser {
  /// The longest lead before a play URL's expiry at which it is renewed (at
  /// most a quarter of its lifetime).
  static const Duration leaseLead = Duration(minutes: 10);

  /// The video qualities of `stream_url`, best first:
  ///
  /// - `stream_data` (`data.{sdk_key}.main`) and the old `flv_pull_url` and
  ///   `hls_pull_url_map` maps are joined by sdk_key, case-insensitively,
  ///   never by position;
  /// - audio-only keys (`ao`, or every URL `only_audio=1`) are left out;
  /// - known keys rank by tier, others by level, then by bit rate;
  /// - keys with the same URLs are one quality, the better-ranked.
  static List<LivePlayQuality> qualities(Map<String, dynamic>? streamUrl) => [
    for (final variant in _variants(streamUrl).list) variant.quality,
  ];

  /// The lines of the quality [qualityId] in `stream_url` issued at
  /// [issuedAt], FLV then HLS as the platform lists them, each with its
  /// format, codec, the media headers of [webRid] and [cookie], its lease and
  /// the declared picture size. An alias id plays its canonical quality; an
  /// id `stream_url` does not have plays the best one (the platform re-keys
  /// per broadcast, so an unknown id is a stale selection, not an error).
  static List<LivePlayLine> lines(
    Map<String, dynamic>? streamUrl, {
    required String webRid,
    required DateTime issuedAt,
    String? qualityId,
    String? cookie,
  }) {
    final variants = _variants(streamUrl);
    final variant = _variantFor(variants, qualityId) ?? variants.list.firstOrNull;
    if (variant == null) return const [];
    final headers = mediaHeaders(webRid, cookie: cookie);
    final used = <LiveStreamFormat, int>{};
    final lines = <LivePlayLine>[];
    for (final line in variant.lines) {
      final index = used[line.format] = (used[line.format] ?? 0) + 1;
      lines.add(
        LivePlayLine(
          url: line.url.toString(),
          format: line.format,
          formatSource: LivePlayFormatSource.declared,
          headers: headers,
          codec: variant.codec,
          lineLabel: index == 1 ? line.format.name : '${line.format.name}-$index',
          lease: lease(line.url, issuedAt),
          geometry: PlayGeometry(width: variant.size?.width, height: variant.size?.height),
        ),
      );
    }
    return lines;
  }

  /// The quality of `stream_url` whose id is [qualityId] or has it as an
  /// alias (keys with the same URLs); null when there is none.
  static LivePlayQuality? qualityFor(Map<String, dynamic>? streamUrl, Object? qualityId) =>
      _variantFor(_variants(streamUrl), qualityId?.toString())?.quality;

  static _Variant? _variantFor(_Variants variants, Object? id) {
    final key = id?.toString().trim().toLowerCase() ?? '';
    if (key.isEmpty) return null;
    final target = variants.aliases[key] ?? key;
    return variants.list.where((variant) => variant.quality.qualityId == target).firstOrNull;
  }

  /// The media request headers of room [webRid] (the player's): UA, Origin,
  /// the room's Referer (the site root without a web_rid) and the cookie when
  /// there is one.
  static Map<String, String> mediaHeaders(String webRid, {String? cookie}) {
    final id = Uri.encodeComponent(webRid.trim());
    return {
      'user-agent': DouyinEndpoints.userAgent,
      'origin': DouyinEndpoints.origin,
      'referer': id.isEmpty ? '${DouyinEndpoints.origin}/' : '${DouyinEndpoints.origin}/$id',
      if (cookie != null && cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
    };
  }

  /// The lease of a play URL received at [issuedAt]. The expiry is an
  /// absolute time in the query: `expire` (decimal or hex Unix seconds),
  /// `volcTime`, `wsTime + keeptime` (hex) or `t` next to a `k` signature;
  /// recorded URLs expire seven days after issue. Values outside a day before
  /// to 31 days after issue are not expiries. Renew [leaseLead] (at most a
  /// quarter of the lifetime) before.
  static LivePlayLease? lease(Uri url, DateTime issuedAt) {
    final expiresAt = _expiry(url.queryParameters, issuedAt);
    if (expiresAt == null) return null;
    final lifetime = expiresAt.difference(issuedAt);
    final lead = lifetime <= Duration.zero
        ? Duration.zero
        : Duration(microseconds: math.min(leaseLead.inMicroseconds, lifetime.inMicroseconds ~/ 4));
    return LivePlayLease(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  static DateTime? _expiry(Map<String, String> query, DateTime issuedAt) {
    DateTime? plausible(int? seconds) {
      if (seconds == null) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      final withinRange =
          at.isAfter(issuedAt.subtract(const Duration(days: 1))) && at.isBefore(issuedAt.add(const Duration(days: 31)));
      return withinRange ? at : null;
    }

    DateTime? time(String? raw) {
      final text = raw?.trim() ?? '';
      if (text.isEmpty) return null;
      final decimal = RegExp(r'^\d+$').hasMatch(text) ? plausible(int.tryParse(text)) : null;
      return decimal ??
          (RegExp(r'^[0-9a-fA-F]{1,12}$').hasMatch(text) ? plausible(int.tryParse(text, radix: 16)) : null);
    }

    final direct = time(query['expire']) ?? time(query['volcTime']);
    if (direct != null) return direct;
    final wsTime = int.tryParse(query['wsTime'] ?? '', radix: 16);
    final keep = int.tryParse(query['keeptime'] ?? '', radix: 16);
    if (wsTime != null && keep != null) {
      final at = plausible(wsTime + keep);
      if (at != null) return at;
    }
    return query.containsKey('k') ? time(query['t']) : null;
  }

  static _Variants _variants(Map<String, dynamic>? streamUrl) {
    if (streamUrl == null) return (list: const <_Variant>[], aliases: const <String, String>{});
    final pull = jsonObject(jsonObject(streamUrl['live_core_sdk_data'])?['pull_data']);
    final options = jsonObject(pull?['options']);
    final streamData = jsonObject(jsonObject(pull?['stream_data'])?['data']) ?? const <String, dynamic>{};
    final flvMap = jsonObject(streamUrl['flv_pull_url']) ?? const <String, dynamic>{};
    final hlsMap = jsonObject(streamUrl['hls_pull_url_map']) ?? const <String, dynamic>{};
    final names = jsonObject(streamUrl['resolution_name']) ?? const <String, dynamic>{};
    final defaultQuality = jsonObject(options?['default_quality']);
    final defaultKey = (jsonText(defaultQuality?['sdk_key']) ?? jsonText(streamUrl['default_resolution']))
        ?.toLowerCase();

    final descriptors = <String, Map<String, dynamic>>{};
    // The id is the lower-case key; the label keeps the platform's spelling.
    final spellings = <String, String>{};
    for (final option in jsonList(options?['qualities'])) {
      final map = jsonObject(option);
      final spelled = jsonText(map?['sdk_key']);
      final key = spelled?.toLowerCase();
      if (map != null && key != null) {
        descriptors.putIfAbsent(key, () => map);
        spellings.putIfAbsent(key, () => spelled!);
      }
    }
    for (final key in {...streamData.keys, ...flvMap.keys, ...hlsMap.keys}) {
      final text = key.trim().toLowerCase();
      if (text.isNotEmpty) {
        descriptors.putIfAbsent(text, () => const <String, dynamic>{});
        spellings.putIfAbsent(text, key.trim);
      }
    }

    final ranked = <_Variant>[];
    for (final entry in descriptors.entries) {
      final key = entry.key;
      final descriptor = entry.value;
      final main = jsonObject(jsonObject(_lookup(streamData, key))?['main']);
      final lines = <_Line>[];
      void add(Object? value, LiveStreamFormat format) {
        final uri = Uri.tryParse(jsonText(value) ?? '');
        if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https')) || uri.host.isEmpty) return;
        if (lines.any((line) => line.url.toString() == uri.toString())) return;
        lines.add((url: uri, format: format));
      }

      add(main?['flv'], LiveStreamFormat.flv);
      add(main?['hls'], LiveStreamFormat.hls);
      add(_lookup(flvMap, key), LiveStreamFormat.flv);
      add(_lookup(hlsMap, key), LiveStreamFormat.hls);
      if (lines.isEmpty || _audioOnly(key, lines)) continue;

      final sdk = jsonObject(main?['sdk_params']) ?? const <String, dynamic>{};
      final codec = _codec(sdk['VCodec']) ?? _codec(descriptor['v_codec']);
      final bitRate = jsonInt(descriptor['v_bit_rate']) ?? jsonInt(sdk['vbitrate']);
      final level = jsonInt(descriptor['level']) ?? 0;
      final tier = _tier(key);
      ranked.add((
        quality: LivePlayQuality(
          label: jsonText(descriptor['name']) ?? jsonText(_lookup(names, key)) ?? spellings[key] ?? key,
          qualityId: key,
          codec: codec,
        ),
        lines: lines,
        codec: codec,
        size: pictureSize(
          main: main,
          descriptor: descriptor,
          defaultQuality: key == defaultKey ? defaultQuality : null,
        ),
        rank: tier > 0
            ? tier
            : level > 0
            ? level * 1000000
            : bitRate ?? 0,
      ));
    }
    ranked.sort((a, b) {
      final byRank = b.rank.compareTo(a.rank);
      return byRank != 0 ? byRank : a.quality.qualityId!.compareTo(b.quality.qualityId ?? '');
    });

    final kept = <_Variant>[];
    final aliases = <String, String>{};
    final bySet = <String, int>{};
    for (final variant in ranked) {
      final set = ([for (final line in variant.lines) line.url.toString()]..sort()).join(String.fromCharCode(31));
      final survivor = bySet[set];
      if (survivor != null) {
        final target = kept[survivor];
        aliases['${variant.quality.qualityId}'] = '${target.quality.qualityId}';
        // The same stream: the survivor takes a codec or a size only the
        // alias reports.
        if ((target.codec == null && variant.codec != null) || (target.size == null && variant.size != null)) {
          kept[survivor] = (
            quality: target.quality,
            lines: target.lines,
            codec: target.codec ?? variant.codec,
            size: target.size ?? variant.size,
            rank: target.rank,
          );
        }
        continue;
      }
      bySet[set] = kept.length;
      kept.add(variant);
    }
    final total = kept.length;
    return (
      list: [
        for (final (index, variant) in kept.indexed)
          (
            quality: variant.quality.copyWith(platformOrder: total - index),
            lines: variant.lines,
            codec: variant.codec,
            size: variant.size,
            rank: variant.rank,
          ),
      ],
      aliases: aliases,
    );
  }

  /// The picture size the platform declares for one quality: `main.width` and
  /// `height`, then `sdk_params.width`/`height`, then `sdk_params.resolution`,
  /// then the quality's `options.qualities[]` `resolution`, then
  /// `default_quality.resolution` when [defaultQuality] is given (the quality
  /// is the default one). A size outside 120–16384 or a ratio outside
  /// 0.30–3.50 does not count. `stream_orientation` and the top-level
  /// `extra.width`/`height` (also on square audio placeholders) are never
  /// read.
  static ({int width, int height})? pictureSize({
    Map<String, dynamic>? main,
    Map<String, dynamic> descriptor = const <String, dynamic>{},
    Map<String, dynamic>? defaultQuality,
  }) {
    final sdk = jsonObject(main?['sdk_params']);
    return _declaredSize(main) ??
        _declaredSize(sdk) ??
        _resolutionSize(sdk?['resolution']) ??
        _resolutionSize(descriptor['resolution']) ??
        _resolutionSize(defaultQuality?['resolution']);
  }

  static ({int width, int height})? _declaredSize(Map<String, dynamic>? map) =>
      map == null ? null : _plausibleSize(jsonInt(_lookup(map, 'width')), jsonInt(_lookup(map, 'height')));

  static ({int width, int height})? _resolutionSize(Object? value) {
    final match = RegExp(r'(\d{2,5})\s*[xX×*]\s*(\d{2,5})').firstMatch(jsonText(value) ?? '');
    if (match == null) return null;
    return _plausibleSize(int.tryParse(match[1]!), int.tryParse(match[2]!));
  }

  static ({int width, int height})? _plausibleSize(int? width, int? height) {
    if (width == null || height == null || width < 120 || height < 120 || width > 16384 || height > 16384) {
      return null;
    }
    final ratio = width / height;
    return ratio < 0.30 || ratio > 3.50 ? null : (width: width, height: height);
  }

  static bool _audioOnly(String key, List<_Line> lines) {
    final token = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');
    if (const {'ao', 'audio', 'audioonly'}.contains(token)) return true;
    return lines.every((line) {
      final value = line.url.queryParameters['only_audio']?.toLowerCase();
      return value == '1' || value == 'true';
    });
  }

  /// The rank of the known sdk keys (a tier above every transcode).
  static int _tier(String key) => switch (key.toUpperCase()) {
    'ORIGION' || 'ORIGIN' => 6000000,
    'FULL_HD1' || 'UHD' => 5000000,
    'HD1' || 'HD' => 4000000,
    'SD2' || 'SD' => 3000000,
    'SD1' || 'LD' => 2000000,
    'MD' => 1000000,
    _ => 0,
  };

  /// `sdk_params.VCodec` (`h264`, `h265`) or `options.qualities[].v_codec`
  /// (`264`, `bytevc1` — ByteDance's HEVC).
  static LiveStreamCodec? _codec(Object? value) =>
      switch (jsonText(value)?.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '')) {
        'h264' || '264' || 'avc' || 'avc1' => LiveStreamCodec.avc,
        'h265' || '265' || 'hevc' || 'hev1' || 'hvc1' || 'bytevc1' => LiveStreamCodec.hevc,
        _ => null,
      };

  static Object? _lookup(Map<String, dynamic> map, String key) {
    final direct = map[key];
    if (direct != null) return direct;
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return null;
  }
}
