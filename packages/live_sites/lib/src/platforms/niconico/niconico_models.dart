import 'package:live_sites/live_sites.dart';

/// One media cookie of a stream grant; it applies to its path only. The HLS
/// master and every playlist, segment and key below it need the cookies of
/// their own path on the media origin (sending all of them in one header is
/// refused with 403).
class NiconicoCookie {
  /// Creates the cookie.
  const new({required this.name, required this.value, required this.path, this.expires});

  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Path prefix (`/hls/playlists/…`, `/hls/segments/…`, `/hls/keys/…`).
  final String path;

  /// Expiry, when given.
  final DateTime? expires;
}

/// One revocable stream grant: the seat's `stream` message. A later `stream`
/// message or the seat's end revokes the grant; its cookies are dropped with
/// it.
class NiconicoGrant {
  /// Creates a grant over [uri] at [quality] with its [cookies].
  new(this.uri, this.quality, this.availableQualities, List<NiconicoCookie> cookies) : _cookies = cookies;

  /// The HLS master on `livedelivery.dlive.nicovideo.jp`.
  final Uri uri;

  /// The quality the seat asked for (`abr`).
  final String quality;

  /// `availableQualities` (`abr`, `super_high`, `1.5Mbps480p30fps`…).
  final List<String> availableQualities;

  final List<NiconicoCookie> _cookies;
  bool _active = true;

  /// Whether the grant was not revoked.
  bool get isActive => _active;

  /// The `Cookie` header for [target] at [now]: the unexpired cookies whose
  /// path is [target]'s path or a parent of it, on exactly the master's
  /// origin, longest path first, then in the order received; null when none
  /// applies or [target] has user info or a fragment. A revoked grant throws a
  /// [SiteStreamUnavailableError].
  String? cookieHeaderFor(Uri target, {DateTime? now}) {
    if (!_active) {
      throw const SiteStreamUnavailableError('niconico: the stream grant was revoked');
    }
    if (target.userInfo.isNotEmpty || target.hasFragment || !target.isScheme('https') || target.host.isEmpty) {
      return null;
    }
    if (target.origin != uri.origin) {
      return null;
    }
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
    if (matching.isEmpty) {
      return null;
    }
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
}

/// The seat's `stream` message and the seat's own control frames, parsed as the
/// reference validated them (protocol, uri, quality list, cookies; each within
/// its size and shape limits).
abstract final class NiconicoStream {
  static final RegExp _qualityName = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
  static final RegExp _cookieName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
  static final RegExp _cookieValue = RegExp(r'^[\x21-\x7e]*$');
  static final RegExp _cookiePath = RegExp(r'^/hls/[A-Za-z0-9_/-]+$');
  static final RegExp _httpDate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d{2}) ([A-Z][a-z]{2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  );

  /// Most cookies in one grant.
  static const int maxCookies = 64;

  /// Most characters of one cookie (origin, name, value and path).
  static const int maxCookieCharacters = 4096;

  /// Most characters of all cookies of a grant.
  static const int maxGrantCharacters = 16 * 1024;

  /// The seat's `stream` message [data] at [now]: `protocol` `hls`; `uri` an
  /// https `.m3u8` under `/hls/playlists/` on `livedelivery.dlive.nicovideo.jp`;
  /// `quality` one of `availableQualities`; at most 64 cookies, each a token
  /// name (not `__Host-`), a printable value without `;`, `"` or `\`, a
  /// `/hls/…` path, domain `nicovideo.jp`, secure, `expires` null or an HTTP
  /// date, no name twice on one path, within the size limits. Anything else is
  /// a [SiteApiChangedError]; cookies already expired at [now] are dropped.
  static NiconicoGrant grant(Map<String, Object?> data, {DateTime? now}) {
    if (data['protocol'] != 'hls') {
      throw SiteApiChangedError('niconico stream: protocol ${data['protocol']}');
    }
    final raw = data['uri'];
    final uri = raw is String && raw.length <= 8192 ? Uri.tryParse(raw) : null;
    if (raw is! String ||
        uri == null ||
        !uri.isScheme('https') ||
        uri.host != 'livedelivery.dlive.nicovideo.jp' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        !uri.path.startsWith('/hls/playlists/') ||
        !uri.path.endsWith('.m3u8') ||
        !raw.startsWith('https://livedelivery.dlive.nicovideo.jp${uri.path}')) {
      throw const SiteApiChangedError('niconico stream: unexpected uri');
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
      throw const SiteApiChangedError('niconico stream: unexpected quality list');
    }
    final rawCookies = data['cookies'];
    if (rawCookies is! List || rawCookies.length > maxCookies) {
      throw const SiteApiChangedError('niconico stream: cookies');
    }
    final at = now ?? DateTime.now();
    final cookies = <NiconicoCookie>[];
    final keys = <(String, String)>{};
    var total = 0;
    for (final entry in rawCookies) {
      if (entry is! Map<String, Object?>) {
        throw const SiteApiChangedError('niconico stream: cookie is not an object');
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
        throw SiteApiChangedError('niconico stream: unexpected cookie ${name is String ? name : ''}');
      }
      final expiry = expires == null ? null : parseHttpDate(expires as String);
      if (expires != null && expiry == null) {
        throw SiteApiChangedError('niconico stream: cookie $name expires "$expires"');
      }
      final size = uri.origin.length + name.length + value.length + path.length;
      total += size;
      if (size > maxCookieCharacters || total > maxGrantCharacters) {
        throw const SiteApiChangedError('niconico stream: cookies too large');
      }
      if (expiry != null && !expiry.isAfter(at)) {
        continue;
      }
      cookies.add(NiconicoCookie(name: name, value: value, path: path, expires: expiry));
    }
    return NiconicoGrant(uri, quality, List.unmodifiable(qualities.cast<String>()), cookies);
  }

  /// `seat.keepIntervalSec`: 1–300 seconds, else a [SiteApiChangedError].
  static int seatInterval(Object? data) {
    final seconds = data is Map ? data['keepIntervalSec'] : null;
    if (seconds is! int || seconds < 1 || seconds > 300) {
      throw SiteApiChangedError('niconico seat: keepIntervalSec $seconds');
    }
    return seconds;
  }

  /// The failure an `error` message reports, by `code`: no permission or a
  /// ticket needed is a [SiteNeedsLoginError], too many connections a
  /// [SiteRateLimitedError], a rejected request a [SiteApiChangedError],
  /// anything else a [SiteStreamUnavailableError].
  static SiteError seatError(Object? data) {
    final code = data is Map ? '${data['code']}' : 'unknown';
    return switch (code) {
      'NO_PERMISSION' || 'NOT_PLAYABLE' || 'TICKET_REQUIRED' => SiteNeedsLoginError('niconico seat error $code'),
      'TOO_MANY_CONNECTIONS' || 'CONNECT_ERROR' => SiteRateLimitedError('niconico seat error $code'),
      'INVALID_STREAM_QUALITY' || 'INVALID_MESSAGE' => SiteApiChangedError('niconico seat error $code'),
      _ => SiteStreamUnavailableError('niconico seat error $code'),
    };
  }

  /// A `disconnect` message (the program ended, the seat was taken…): a
  /// [SiteStreamUnavailableError] with its reason.
  static SiteError seatDisconnect(Object? data) =>
      SiteStreamUnavailableError('niconico seat disconnect ${data is Map ? data['reason'] : ''}'.trim());

  /// Whether [reason] is a seat disconnect naming `END_PROGRAM` (the program
  /// ended; the danmaku connection treats it as an end, not a failure).
  static bool isProgramEnd(Object? reason) =>
      reason is SiteStreamUnavailableError && reason.message.endsWith('END_PROGRAM');

  /// An RFC 1123 HTTP date (`Mon, 28 Sep 2026 18:41:00 GMT`) in UTC, or null.
  static DateTime? parseHttpDate(String text) {
    final match = _httpDate.firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    final month = _months.indexOf(match.group(2)!) + 1;
    final day = int.parse(match.group(1)!);
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (month == 0 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
      return null;
    }
    final date = DateTime.utc(year, month, day, hour, minute, second);
    return date.day == day ? date : null;
  }

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
}
