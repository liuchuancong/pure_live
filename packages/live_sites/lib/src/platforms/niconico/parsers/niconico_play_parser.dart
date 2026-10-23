import 'dart:convert';

import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_json.dart';

// The value wrappers spell their class name in their constructors; the `.new`
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One media cookie of a stream grant; it applies to its path only.
final class NiconicoCookie {
  /// Creates the cookie.
  const NiconicoCookie({required this.name, required this.value, required this.path, this.expires});

  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Path prefix (`/hls/playlists/…`, `/hls/segments/…`, `/hls/keys/…`).
  final String path;

  /// Expiry, when the grant gave one.
  final DateTime? expires;

  @override
  String toString() => 'NiconicoCookie($name, $path)';
}

/// One revocable stream grant: the seat's `stream` message. The HLS master and
/// every playlist, segment and key below it need the cookies of their own path
/// on the media origin (all of them in one header is refused with 403). A
/// later `stream` message or the seat's end [revoke]s the grant; its cookies
/// go with it. Mutable (it can be revoked), so it stays value-uncomparable.
final class NiconicoGrant {
  NiconicoGrant._(this.uri, this.quality, this.availableQualities, this._cookies);

  /// The HLS master on `livedelivery.dlive.nicovideo.jp`.
  final Uri uri;

  /// The quality the seat asked for (`abr`).
  final String quality;

  /// The selectable video qualities (`abr`, `super_high`, …), audio-only
  /// names dropped.
  final List<String> availableQualities;

  final List<NiconicoCookie> _cookies;
  bool _active = true;

  /// Whether the grant has not been revoked.
  bool get isActive => _active;

  /// The cookies kept (none after [revoke]).
  List<NiconicoCookie> get cookies => List<NiconicoCookie>.unmodifiable(_cookies);

  /// The soonest cookie expiry, or null when none expires: the grant's lease,
  /// when its media URL must be re-resolved through a new seat.
  DateTime? get leaseExpiresAt {
    DateTime? soonest;
    for (final cookie in _cookies) {
      final expiry = cookie.expires;
      if (expiry != null && (soonest == null || expiry.isBefore(soonest))) soonest = expiry;
    }
    return soonest;
  }

  /// The `Cookie` header for [target] at [now]: the unexpired cookies whose
  /// path is [target]'s path or a parent of it, on exactly the master's origin,
  /// longest path first then in the order received; null when none applies or
  /// [target] has user info or a fragment. A revoked grant throws
  /// [NiconicoFailureKind.streamUnavailable].
  String? cookieHeaderFor(Uri target, {DateTime? now}) {
    if (!_active) {
      throw const NiconicoFailure(NiconicoFailureKind.streamUnavailable, 'the stream grant was revoked');
    }
    if (target.userInfo.isNotEmpty || target.hasFragment || !target.isScheme('https') || target.host.isEmpty) {
      return null;
    }
    if (target.origin != uri.origin) return null;
    final at = now ?? DateTime.now();
    final matching =
        [
          for (final (index, cookie) in _cookies.indexed)
            if (_pathMatches(target.path, cookie.path) && (cookie.expires == null || cookie.expires!.isAfter(at)))
              (index: index, cookie: cookie),
        ]..sort((a, b) {
          final byPath = b.cookie.path.length.compareTo(a.cookie.path.length);
          return byPath != 0 ? byPath : a.index.compareTo(b.index);
        });
    if (matching.isEmpty) return null;
    return [for (final entry in matching) '${entry.cookie.name}=${entry.cookie.value}'].join('; ');
  }

  /// Drops the cookies; later [cookieHeaderFor] calls throw.
  void revoke() {
    _active = false;
    _cookies.clear();
  }

  static bool _pathMatches(String request, String cookie) =>
      request == cookie ||
      (request.startsWith(cookie) && (cookie.endsWith('/') || request.substring(cookie.length).startsWith('/')));

  @override
  String toString() => 'NiconicoGrant(${uri.host}, $quality, ${_cookies.length} cookies)';
}

/// One video variant of the master playlist: its resolution, its `BANDWIDTH`
/// and the variant playlist URL, resolved against the master.
typedef NiconicoVariant = ({String url, int width, int height, int bandwidth});

/// Pure parsing of niconico's playback side: the seat's `stream` message
/// (protocol `hls`, the master URI, `availableQualities` and the path-scoped
/// media cookies), the hand-rolled `EXT-X-STREAM-INF` master parse into
/// qualities and lines, and the RFC 1123 HTTP dates the cookies expire on.
abstract final class NiconicoPlayParser {
  static final RegExp _qualityName = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
  static final RegExp _cookieName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
  static final RegExp _cookieValue = RegExp(r'^[\x21-\x7e]*$');
  static final RegExp _cookiePath = RegExp(r'^/hls/[A-Za-z0-9_/-]+$');
  static final RegExp _resolution = RegExp(r'^([1-9]\d{0,4})x([1-9]\d{0,4})$');

  /// Most cookies in one grant.
  static const int maxCookies = 64;

  /// The seat's `stream` message [data] at [now] as a [NiconicoGrant]:
  /// `protocol` must be `hls`; `uri` an https `.m3u8` under `/hls/playlists/`
  /// on the media host without port, credentials or fragment; `quality` one of
  /// `availableQualities` (1–32 distinct names, audio-only ones dropped from
  /// the offered set); at most [maxCookies] `cookies`, each a token name (not
  /// `__Host-`), a printable value without `;` `"` or `\`, a `/hls/…` path,
  /// domain `nicovideo.jp`, secure, `expires` null or an HTTP date. Anything
  /// else is `apiChanged`; cookies already expired at [now] are dropped.
  static NiconicoGrant grant(Map<String, dynamic> data, {DateTime? now}) {
    if (data['protocol'] != 'hls') {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: protocol ${data['protocol']}');
    }
    final raw = data['uri'];
    final uri = raw is String && raw.length <= 8192 ? Uri.tryParse(raw) : null;
    if (raw is! String ||
        uri == null ||
        !uri.isScheme('https') ||
        uri.host != NiconicoEndpoints.mediaHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        !uri.path.startsWith('/hls/playlists/') ||
        !uri.path.endsWith('.m3u8') ||
        !raw.startsWith('https://${NiconicoEndpoints.mediaHost}${uri.path}')) {
      throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: unexpected uri');
    }
    final quality = data['quality'];
    final qualities = data['availableQualities'];
    if (quality is! String ||
        !_qualityName.hasMatch(quality) ||
        qualities is! List ||
        qualities.isEmpty ||
        qualities.length > 32 ||
        qualities.any((value) => value is! String || !_qualityName.hasMatch(value)) ||
        qualities.toSet().length != qualities.length ||
        !qualities.contains(quality)) {
      throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: unexpected quality list');
    }
    final rawCookies = data['cookies'];
    if (rawCookies is! List || rawCookies.length > maxCookies) {
      throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: cookies');
    }
    final at = now ?? DateTime.now();
    final cookies = <NiconicoCookie>[];
    final keys = <(String, String)>{};
    for (final entry in rawCookies) {
      if (entry is! Map<String, dynamic>) {
        throw const NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: cookie is not an object');
      }
      final name = entry['name'];
      final value = entry['value'];
      final path = entry['path'];
      final domain = entry['domain'];
      final expires = entry['expires'];
      if (name is! String ||
          !_cookieName.hasMatch(name) ||
          name.startsWith('__Host-') ||
          value is! String ||
          !_cookieValue.hasMatch(value) ||
          value.contains(';') ||
          value.contains('"') ||
          value.contains(r'\') ||
          path is! String ||
          !_cookiePath.hasMatch(path) ||
          (domain != 'nicovideo.jp' && domain != '.nicovideo.jp') ||
          entry['secure'] != true ||
          (expires != null && expires is! String) ||
          !keys.add((path, name))) {
        throw NiconicoFailure(
          NiconicoFailureKind.apiChanged,
          'stream: unexpected cookie ${name is String ? name : ''}',
        );
      }
      final expiry = expires == null ? null : parseHttpDate(expires as String);
      if (expires != null && expiry == null) {
        throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'stream: cookie $name expires "$expires"');
      }
      if (expiry != null && !expiry.isAfter(at)) continue;
      cookies.add(NiconicoCookie(name: name, value: value, path: path, expires: expiry));
    }
    return NiconicoGrant._(
      uri,
      quality,
      List<String>.unmodifiable([
        for (final name in qualities.cast<String>())
          if (!name.startsWith('audio_')) name,
      ]),
      cookies,
    );
  }

  /// `seat.keepIntervalSec`: 1–300 seconds, else `apiChanged`.
  static int seatInterval(Object? data) {
    final seconds = data is Map ? data['keepIntervalSec'] : null;
    if (seconds is! int || seconds < 1 || seconds > 300) {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'seat: keepIntervalSec $seconds');
    }
    return seconds;
  }

  /// The failure an `error` seat message reports, by `code`: no permission or
  /// a ticket needed needs a login, too many connections is rate limited, a
  /// rejected message is `apiChanged`, anything else is stream-unavailable.
  static NiconicoFailure seatError(Object? data) {
    final code = data is Map ? '${data['code']}' : 'unknown';
    return NiconicoFailure(switch (code) {
      'NO_PERMISSION' || 'NOT_PLAYABLE' || 'TICKET_REQUIRED' => NiconicoFailureKind.needsLogin,
      'TOO_MANY_CONNECTIONS' || 'CONNECT_ERROR' => NiconicoFailureKind.rateLimited,
      'INVALID_STREAM_QUALITY' || 'INVALID_MESSAGE' => NiconicoFailureKind.apiChanged,
      _ => NiconicoFailureKind.streamUnavailable,
    }, 'seat error $code');
  }

  /// A `disconnect` seat message (the program ended, the seat was taken…):
  /// stream-unavailable with its reason.
  static NiconicoFailure seatDisconnect(Object? data) => NiconicoFailure(
    NiconicoFailureKind.streamUnavailable,
    'seat disconnect ${data is Map ? data['reason'] : ''}'.trim(),
  );

  // Master playlist -----------------------------------------------------------

  /// The video variants of the master playlist [body] read from [source], best
  /// first (height, then bandwidth). A refused or gone master (401/403 risk,
  /// 404/410 unavailable, 429 rate, 5xx network) throws its [NiconicoFailure];
  /// a body that is not a playlist is `apiChanged`, and a playlist with no
  /// usable variant is stream-unavailable.
  static List<NiconicoVariant> variants(String body, {required Uri source, int status = 200}) {
    switch (status) {
      case 200:
        break;
      case 401 || 403:
        throw NiconicoFailure(NiconicoFailureKind.riskControl, 'master: HTTP $status');
      case 404 || 410:
        throw NiconicoFailure(NiconicoFailureKind.streamUnavailable, 'master: HTTP $status');
      case 429:
        throw const NiconicoFailure(NiconicoFailureKind.rateLimited, 'master: HTTP 429');
      case >= 500:
        throw NiconicoFailure(NiconicoFailureKind.network, 'master: HTTP $status');
      default:
        throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'master: HTTP $status (${jsonSnippet(body)})');
    }
    final lines = const LineSplitter().convert(body).map((line) => line.trim()).toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') {
      throw NiconicoFailure(NiconicoFailureKind.apiChanged, 'master: not a playlist (${jsonSnippet(body)})');
    }
    // The master is read through the shared HLS parser; a body that is not a
    // master playlist yields no variants and falls to the stream-unavailable
    // answer below. Relative URIs are resolved against the source here so no
    // part of the master's own query is copied onto a variant.
    final parsed = parseHlsMaster(body, masterUrl: source);
    final variants = <String, NiconicoVariant>{};
    for (final entry in parsed?.master.variants ?? const <HlsVariant>[]) {
      final url = resolveHlsVariantUri(entry.uri, master: source);
      final bandwidth = entry.bandwidth;
      final width = entry.width;
      final height = entry.height;
      if (url.scheme != 'https' ||
          url.host.isEmpty ||
          bandwidth <= 0 ||
          width == null ||
          height == null ||
          !_resolution.hasMatch('${width}x$height')) {
        continue;
      }
      final key = '${width}x$height@$bandwidth';
      variants[key] = (url: '$url', width: width, height: height, bandwidth: bandwidth);
    }
    if (variants.isEmpty) {
      throw const NiconicoFailure(NiconicoFailureKind.streamUnavailable, 'master: no video variant');
    }
    final result = variants.values.toList()
      ..sort((a, b) {
        final byHeight = b.height.compareTo(a.height);
        return byHeight != 0 ? byHeight : b.bandwidth.compareTo(a.bandwidth);
      });
    return result;
  }

  /// The [variants] as qualities, best first: the id is `WxH@BANDWIDTH` (a
  /// re-read master names the same variant), the label the resolution.
  static List<LivePlayQuality> qualities(List<NiconicoVariant> variants) {
    final total = variants.length;
    return [
      for (final (index, variant) in variants.indexed)
        LivePlayQuality.of(
          label: '${variant.width}x${variant.height}',
          qualityId: '${variant.width}x${variant.height}@${variant.bandwidth}',
          platformOrder: total - index,
        ),
    ];
  }

  /// The variant [qualityId] names (the id, `WxH@BANDWIDTH`), else the best
  /// one, or null when there are no [variants].
  static NiconicoVariant? pick(List<NiconicoVariant> variants, String? qualityId) {
    if (variants.isEmpty) return null;
    final id = qualityId?.trim() ?? '';
    if (id.isEmpty) return variants.first;
    return variants.where((variant) => '${variant.width}x${variant.height}@${variant.bandwidth}' == id).firstOrNull ??
        variants.first;
  }

  /// The playable line of the master the seat granted: [variant]'s playlist URL
  /// with the cookies of [grant] that apply to it (its `Cookie` header), the
  /// media headers of room [roomId], HLS as the master declares, and the
  /// grant's cookie expiry as the lease (a new seat revokes it).
  static List<LivePlayLine> lines(
    NiconicoGrant grant,
    NiconicoVariant variant, {
    required String roomId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final target = Uri.parse(variant.url);
    final cookie = grant.cookieHeaderFor(target, now: at);
    return [
      LivePlayLine.of(
        url: variant.url,
        format: LiveStreamFormat.hls,
        formatSource: LivePlayFormatSource.declared,
        headers: {
          'user-agent': NiconicoEndpoints.userAgent,
          'referer': '${NiconicoEndpoints.origin}/watch/${roomId.trim()}',
          'cookie': ?cookie,
        },
        lineLabel: grant.uri.host,
        lease: lease(expiresAt: grant.leaseExpiresAt, now: at),
      ),
    ];
  }

  /// The lease of a grant whose cookies die at [expiresAt]: refresh one minute
  /// early (never in the past); null when no cookie expires.
  static LivePlayLease? lease({required DateTime now, DateTime? expiresAt}) {
    if (expiresAt == null) return null;
    final refresh = expiresAt.subtract(const Duration(minutes: 1));
    return LivePlayLease.of(refreshAt: refresh.isAfter(now) ? refresh : expiresAt, expiresAt: expiresAt);
  }

  // Helpers -------------------------------------------------------------------

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static final RegExp _httpDate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d{2}) ([A-Z][a-z]{2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  );

  /// An RFC 1123 HTTP date (`Mon, 28 Sep 2026 18:41:00 GMT`) in UTC, or null.
  static DateTime? parseHttpDate(String text) {
    final match = _httpDate.firstMatch(text.trim());
    if (match == null) return null;
    final month = _months.indexOf(match.group(2)!) + 1;
    final parts = [
      for (final group in [1, 3, 4, 5, 6]) int.parse(match.group(group)!),
    ];
    final day = parts[0];
    final year = parts[1];
    final hour = parts[2];
    final minute = parts[3];
    final second = parts[4];
    if (month == 0 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) return null;
    final date = DateTime.utc(year, month, day, hour, minute, second);
    return date.day == day ? date : null;
  }
}
