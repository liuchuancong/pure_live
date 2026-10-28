import 'dart:math' as math;

import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_json.dart';

/// One media URL of a quality, with the codec its descriptor (or its file
/// name) names.
typedef _Line = ({Uri uri, String url, LiveStreamCodec? codec});

/// One quality before it is ranked: the (name, sort) it merges under, the
/// lines it offers (CDN lines), its codec, and whether it is an H.265 tier the
/// H.264 set lacks.
typedef _Tier = ({String key, String name, int sort, List<_Line> lines, LiveStreamCodec? codec, bool hevcOnly});

/// The ` · H.265` suffix an H.265-only quality of a room page carries, so a
/// saved H.264 preference never lands on it.
const String _hevcSuffix = ' · H.265';

/// Pure parsing of Kuaishou's `playUrls`: a room page carries `{h264, hevc}`
/// each with `adaptationSet.representation[]`, a card a descriptor list. There
/// is no anti-leech generation and no play request — the signed URLs ride in
/// the room answer, and each one's own query says when it expires.
abstract final class KuaishouPlayParser {
  /// How long before a play URL's expiry it is renewed (at most a quarter of
  /// its lifetime).
  static const Duration leaseLead = Duration(minutes: 10);

  /// The qualities of a `playUrls` value, best first:
  ///
  /// - per descriptor the first of `h264`, `avc`, `hevc`, `h265` that has
  ///   representations, else the descriptor itself;
  /// - only absolute `http://` and `https://` URLs;
  /// - `sort` is `level`, else `bitrate`, else 0; the name is `name`, else
  ///   `shortName`, else `qualityType`, else `清晰度 {sort}`;
  /// - one quality per (name, sort), its URLs merged in order without repeats
  ///   (descriptors are CDN lines); the quality id is the name, a NUL and the
  ///   sort;
  /// - a room page's H.265 qualities the H.264 set lacks are added with
  ///   “ · H.265” after the name and in the id; with [preferH264] (on by
  ///   default) they come after every H.264 quality, else by sort.
  static List<LivePlayQuality> qualities(Object? playUrls, {bool preferH264 = true}) {
    final tiers = _tiers(playUrls, preferH264: preferH264);
    final total = tiers.length;
    return [
      for (final (index, tier) in tiers.indexed)
        LivePlayQuality.of(
          label: tier.name + (tier.hevcOnly ? _hevcSuffix : ''),
          qualityId: tier.key,
          codec: tier.codec,
          platformOrder: total - index,
        ),
    ];
  }

  /// The lines of the quality [qualityId] in [playUrls] (the quality with the
  /// same id; else the next lower one, else the highest), received at
  /// [issuedAt] for streamer [roomId]. Lines keep one codec (the first known
  /// one), carry the media headers with the user's [cookie], the CDN host as
  /// the line label and the lease of their signature. An empty list means the
  /// page has no playable representation.
  static List<LivePlayLine> lines(
    Object? playUrls, {
    required String roomId,
    required DateTime issuedAt,
    String? qualityId,
    String? cookie,
  }) {
    final tiers = _tiers(playUrls);
    if (tiers.isEmpty) return const [];
    final tier = _choose(tiers, qualityId);
    final headers = mediaHeaders(roomId, cookie: cookie);
    final codec = tier.lines.map((line) => line.codec).nonNulls.firstOrNull;
    final hosts = <String, int>{};
    final lines = <LivePlayLine>[];
    for (final line in tier.lines) {
      if (codec != null && line.codec != null && line.codec != codec) continue;
      final count = hosts.update(line.uri.host, (value) => value + 1, ifAbsent: () => 1);
      lines.add(
        LivePlayLine.of(
          url: line.url,
          format: line.uri.path.toLowerCase().endsWith('.m3u8') ? LiveStreamFormat.hls : LiveStreamFormat.flv,
          formatSource: LivePlayFormatSource.inferred,
          headers: headers,
          codec: line.codec ?? codec,
          lineLabel: count == 1 ? line.uri.host : '${line.uri.host}#$count',
          lease: lease(line.uri, issuedAt),
        ),
      );
    }
    return lines;
  }

  /// Media request headers for streamer [roomId]: a desktop Chrome UA, the
  /// web origin, the room page as Referer, and the cookie only when the user
  /// configured one (the anonymous session never goes to the CDN).
  static Map<String, String> mediaHeaders(String roomId, {String? cookie}) {
    final id = roomId.trim();
    final value = cookie?.replaceAll(_controlCharacters, '').trim() ?? '';
    return {
      'user-agent': KuaishouEndpoints.mediaUserAgent,
      'origin': KuaishouEndpoints.origin,
      'referer': id.isEmpty ? '${KuaishouEndpoints.origin}/' : KuaishouEndpoints.roomPageUrl(id),
      if (value.isNotEmpty) 'cookie': value,
    };
  }

  /// The lease of a media URL received at [issuedAt]: the signature expiry is
  /// `txTime`, `wsTime` or `hwTime` (8 hex digits), `ty_Time` or the
  /// `bd-origin` `wsTime` (10 decimal digits), or the first field of the
  /// `ali-origin` `auth_key`; about 24 hours after issue. Renew [leaseLead]
  /// (at most a quarter of the lifetime) before. No expiry, or one already
  /// past, is no lease.
  static LivePlayLease? lease(Uri url, DateTime issuedAt, {bool allowExpired = false}) {
    final expiry = _expiry(url.query);
    if (expiry == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) {
      return allowExpired ? LivePlayLease.of(refreshAt: expiresAt.subtract(leaseLead), expiresAt: expiresAt) : null;
    }
    final lead = Duration(microseconds: math.min(leaseLead.inMicroseconds, lifetime.inMicroseconds ~/ 4));
    return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  /// The codec of a card URL (card descriptors name none): the part of the
  /// file name after the last `_` starts with letters and the codec
  /// (`{id}_GameAvcSdL1.flv`, `…_ShowAvc…`, `…_EcAvc…`); `{id}_ma1500.flv`
  /// names none.
  static LiveStreamCodec? _codecOf(Uri url) {
    final file = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    return switch (_pathCodec.firstMatch(file.split('_').last)?.group(1)) {
      'Avc' || 'H264' => LiveStreamCodec.avc,
      'Hevc' || 'H265' => LiveStreamCodec.hevc,
      _ => null,
    };
  }

  /// The representations of a descriptor: `adaptationSet.representation`, else
  /// the descriptor's own `representation`, else empty.
  static List<Object?> _representations(Object? descriptor) {
    final map = jsonObject(descriptor);
    if (map == null) return const [];
    final set = jsonObject(map['adaptationSet']);
    return jsonList(set == null ? map['representation'] : set['representation']);
  }

  /// The tiers of [playUrls], best first; with [preferH264] the H.265 tiers
  /// (`hevcOnly`) follow every other tier.
  static List<_Tier> _tiers(Object? playUrls, {bool preferH264 = true}) {
    final merged = <String, _Tier>{};
    final hevc = <Object?>[];
    for (final raw in playUrls is List ? playUrls : [playUrls]) {
      final descriptor = jsonObject(raw);
      if (descriptor == null) continue;
      Object? chosen = descriptor;
      LiveStreamCodec? keyCodec;
      for (final (key, codec) in const [
        ('h264', LiveStreamCodec.avc),
        ('avc', LiveStreamCodec.avc),
        ('hevc', LiveStreamCodec.hevc),
        ('h265', LiveStreamCodec.hevc),
      ]) {
        if (_representations(descriptor[key]).isNotEmpty) {
          chosen = descriptor[key];
          keyCodec = codec;
          break;
        }
      }
      _addTiers(merged, _representations(chosen), keyCodec);
      if (keyCodec == LiveStreamCodec.avc) {
        final hevcSet = _representations(descriptor['hevc']);
        hevc.addAll(_representations(hevcSet.isNotEmpty ? descriptor['hevc'] : descriptor['h265']));
      }
    }
    // H.265 qualities the H.264 set lacks (4K, 蓝光 质臻 on some rooms), apart
    // from the H.264 names so a saved preference never lands on them.
    final extra = <String, _Tier>{};
    _addTiers(extra, hevc, LiveStreamCodec.hevc, hevcOnly: true);
    extra.removeWhere((_, tier) => merged.containsKey('${tier.name}$_nul${tier.sort}'));
    final ordered = [...merged.values, ...extra.values].indexed.toList()
      ..sort((a, b) {
        if (preferH264 && a.$2.hevcOnly != b.$2.hevcOnly) return a.$2.hevcOnly ? 1 : -1;
        final bySort = b.$2.sort.compareTo(a.$2.sort);
        return bySort != 0 ? bySort : a.$1.compareTo(b.$1);
      });
    return [for (final (_, tier) in ordered) tier];
  }

  /// Adds [representations] to [tiers] by (name, sort); [codec] is the
  /// descriptor's, else read from each URL. [hevcOnly] tiers are keyed by
  /// their name with the H.265 suffix.
  static void _addTiers(
    Map<String, _Tier> tiers,
    List<Object?> representations,
    LiveStreamCodec? codec, {
    bool hevcOnly = false,
  }) {
    for (final value in representations) {
      final item = jsonObject(value);
      if (item == null) continue;
      final url = item['url']?.toString().trim() ?? '';
      final uri = _mediaUri(url);
      if (uri == null) continue;
      final sort = jsonInt(item['level']) ?? jsonInt(item['bitrate']) ?? 0;
      final name =
          jsonString(item['name']) ?? jsonString(item['shortName']) ?? jsonString(item['qualityType']) ?? '清晰度 $sort';
      final key = '${hevcOnly ? '$name$_hevcSuffix' : name}$_nul$sort';
      final tier = tiers.putIfAbsent(
        key,
        () => (key: key, name: name, sort: sort, lines: <_Line>[], codec: codec, hevcOnly: hevcOnly),
      );
      if (tier.lines.every((line) => line.url != url)) {
        tier.lines.add((uri: uri, url: url, codec: codec ?? _codecOf(uri)));
      }
    }
  }

  /// An absolute `http://` or `https://` URL (the platform's check: the prefix,
  /// and `Uri.isAbsolute`), or null.
  static Uri? _mediaUri(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    final uri = Uri.tryParse(url);
    return uri != null && uri.isAbsolute && uri.host.isNotEmpty ? uri : null;
  }

  /// The tier with [qualityId]'s key, else the next lower one (H.265-only tiers
  /// only when there is nothing else), else the highest.
  static _Tier _choose(List<_Tier> tiers, String? qualityId) {
    final id = qualityId?.trim() ?? '';
    for (final tier in tiers) {
      if (tier.key == id) return tier;
    }
    final pool = tiers.where((tier) => !tier.hevcOnly).toList();
    final candidates = pool.isEmpty ? tiers : pool;
    final wanted = _sortOfKey(id);
    for (final tier in candidates) {
      if (tier.sort <= wanted) return tier;
    }
    return candidates.first;
  }

  /// The sort a quality id carries after its NUL (0 when it names none).
  static int _sortOfKey(String key) {
    final cut = key.lastIndexOf(_nul);
    return cut < 0 ? 0 : int.tryParse(key.substring(cut + 1)) ?? 0;
  }

  /// The Unix-seconds expiry in a media URL's [query]: `txTime`, `wsTime` or
  /// `hwTime` (8 hex digits) or `ty_Time` (10 decimal digits), or the first
  /// field of the `ali-origin` `auth_key`; null when none reads.
  static int? _expiry(String query) {
    String? parameter(String name) =>
        RegExp('(?:^|&)${RegExp.escape(name)}=([^&]*)').firstMatch(query)?.group(1)?.trim();
    for (final key in const ['txTime', 'wsTime', 'hwTime', 'ty_Time']) {
      final value = parameter(key);
      if (value == null) continue;
      if (_decimalTime.hasMatch(value)) return int.parse(value);
      if (_hexTime.hasMatch(value)) return int.parse(value, radix: 16);
    }
    final authKey = _authKeyTime.firstMatch(parameter('auth_key') ?? '');
    return authKey == null ? null : int.parse(authKey.group(1)!);
  }

  /// The NUL that separates a quality id's name from its sort.
  static final String _nul = String.fromCharCode(0);

  static final RegExp _pathCodec = RegExp('^[A-Za-z]*?(Avc|Hevc|H264|H265)');
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _decimalTime = RegExp(r'^\d{10}$');
  static final RegExp _hexTime = RegExp(r'^[0-9a-fA-F]{8}$');
  static final RegExp _authKeyTime = RegExp(r'^(\d{10})-');
}
