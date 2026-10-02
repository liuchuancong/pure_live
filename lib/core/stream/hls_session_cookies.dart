import 'dart:io';

/// Bounded, in-memory cookies for one HLS relay, never a browser/account jar.
///
/// Deliberately pin even Domain cookies to the issuing origin. A playlist may
/// reference arbitrary CDN hosts; it must not grant one host access to another
/// host's session. Cross-origin cookie sharing is not supported by this relay.
class HlsSessionCookies {
  HlsSessionCookies({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maximumCount = 64;
  static const maximumCharacters = 16 * 1024;
  static const maximumCookieCharacters = 4096;
  final DateTime Function() _now;
  final Map<(String, String, String), _SessionCookie> _cookies = {};
  int _sequence = 0;

  int get count => _cookies.length;
  int get retainedCharacters => _cookies.values.fold(0, (sum, cookie) => sum + cookie.size);

  void clear() => _cookies.clear();

  void receive(Uri uri, Iterable<String> values) {
    final now = _now();
    _prune(now);
    for (final value in values) {
      if (value.length > maximumCookieCharacters) continue;
      final Cookie cookie;
      try {
        cookie = Cookie.fromSetCookieValue(value);
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      } on HttpException {
        continue;
      }
      if (cookie.name.isEmpty) continue;
      var domain = cookie.domain?.toLowerCase();
      if (domain != null) {
        if (domain.startsWith('.')) domain = domain.substring(1);
        final exact = uri.host == domain;
        final parent = InternetAddress.tryParse(uri.host) == null && uri.host.endsWith('.$domain');
        if (domain.isEmpty || (!exact && !parent)) continue;
      }
      if (cookie.secure && uri.scheme != 'https') continue;
      if (cookie.name.startsWith('__Secure-') && (!cookie.secure || uri.scheme != 'https')) continue;
      if (cookie.name.startsWith('__Host-') &&
          (!cookie.secure || uri.scheme != 'https' || domain != null || cookie.path != '/')) {
        continue;
      }
      final path = cookie.path?.startsWith('/') == true ? cookie.path! : _defaultPath(uri.path);
      final key = (uri.origin, path, cookie.name);
      // Max-Age takes precedence over Expires. Cap extreme lifetime values to
      // one year before arithmetic, avoiding hostile integer overflow.
      final expires = cookie.maxAge == null
          ? cookie.expires
          : now.add(Duration(seconds: cookie.maxAge!.clamp(0, 365 * 24 * 60 * 60)));
      final previous = _cookies.remove(key);
      if (expires != null && !expires.isAfter(now)) continue;
      final entry = _SessionCookie(
        origin: uri.origin,
        path: path,
        name: cookie.name,
        value: cookie.value,
        expires: expires,
        sequence: previous?.sequence ?? _sequence++,
      );
      if (entry.size > maximumCookieCharacters) continue;
      _cookies[key] = entry;
      while (_cookies.length > maximumCount || retainedCharacters > maximumCharacters) {
        _cookies.remove(_cookies.keys.first);
      }
    }
  }

  /// New session values replace same-name caller values. Only the caller's
  /// original origin may supply [initialHeader] (enforced by the relay).
  String? headerFor(Uri uri, {String? initialHeader}) {
    _prune(_now());
    final selected =
        _cookies.values.where((cookie) => cookie.origin == uri.origin && _pathMatches(uri.path, cookie.path)).toList()
          ..sort((a, b) {
            final pathOrder = b.path.length.compareTo(a.path.length);
            return pathOrder != 0 ? pathOrder : a.sequence.compareTo(b.sequence);
          });
    final names = selected.map((cookie) => cookie.name).toSet();
    final initial = (initialHeader ?? '').split(';').map((pair) => pair.trim()).where((pair) {
      final separator = pair.indexOf('=');
      return separator > 0 && !names.contains(pair.substring(0, separator).trim());
    });
    final pairs = [...selected.map((cookie) => '${cookie.name}=${cookie.value}'), ...initial];
    return pairs.isEmpty ? null : pairs.join('; ');
  }

  void _prune(DateTime now) =>
      _cookies.removeWhere((_, cookie) => cookie.expires != null && !cookie.expires!.isAfter(now));

  static String _defaultPath(String path) {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : path.substring(0, lastSlash);
  }

  static bool _pathMatches(String request, String cookie) =>
      request == cookie ||
      (request.startsWith(cookie) && (cookie.endsWith('/') || request.substring(cookie.length).startsWith('/')));
}

class _SessionCookie {
  const _SessionCookie({
    required this.origin,
    required this.path,
    required this.name,
    required this.value,
    required this.expires,
    required this.sequence,
  });

  final String origin;
  final String path;
  final String name;
  final String value;
  final DateTime? expires;
  final int sequence;
  int get size => origin.length + path.length + name.length + value.length;
}
