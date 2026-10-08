import 'dart:io';

import 'package:pure_live/core/stream/hls_session_cookies.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

/// One revocable stream grant. Cookies never enter the shared Dio/account jar.
/// The observed domain cookies are intentionally narrowed to this media origin.
class NiconicoStream {
  NiconicoStream._(this.uri, this.quality, this.availableQualities, this._cookies);
  final Uri uri;
  final String quality;
  final List<String> availableQualities;
  final HlsSessionCookies _cookies;
  bool _active = true;
  bool get isActive => _active;
  int get retainedCookieCount => _cookies.count;

  String? cookieHeaderFor(Uri target) {
    if (!_active) throw const NiconicoException(NiconicoFailure.sessionClosed);
    if (target.userInfo.isNotEmpty || target.hasFragment) return null;
    return _cookies.headerFor(target);
  }

  void close() {
    _active = false;
    _cookies.clear();
  }

  static NiconicoStream parse(Map<String, dynamic> data, {DateTime Function()? now}) {
    if (data['protocol'] != 'hls') throw const NiconicoException(NiconicoFailure.schema);
    final raw = data['uri'];
    final uri = raw is String && raw.length <= 8192 ? Uri.tryParse(raw) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'livedelivery.dlive.nicovideo.jp' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        !uri.path.startsWith('/hls/playlists/') ||
        !uri.path.endsWith('.m3u8') ||
        !(raw as String).startsWith('https://livedelivery.dlive.nicovideo.jp${uri.path}')) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    final quality = data['quality'];
    final qualities = data['availableQualities'];
    final validQuality = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
    if (quality is! String ||
        !validQuality.hasMatch(quality) ||
        qualities is! List ||
        qualities.isEmpty ||
        qualities.length > 32 ||
        qualities.any((value) => value is! String || !validQuality.hasMatch(value)) ||
        qualities.toSet().length != qualities.length ||
        !qualities.contains(quality)) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    final rawCookies = data['cookies'];
    if (rawCookies is! List || rawCookies.length > HlsSessionCookies.maximumCount) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    final headers = <String>[];
    final keys = <(String, String)>{};
    var retainedSize = 0;
    for (final entry in rawCookies) {
      if (entry is! Map<String, dynamic>) throw const NiconicoException(NiconicoFailure.schema);
      final name = entry['name'];
      final value = entry['value'];
      final path = entry['path'];
      final domain = entry['domain'];
      final expires = entry['expires'];
      if (name is! String ||
          !RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(name) ||
          name.startsWith('__Host-') ||
          value is! String ||
          !RegExp(r'^[\x21-\x7e]*$').hasMatch(value) ||
          value.contains(';') ||
          value.contains('"') ||
          value.contains(r'\') ||
          path is! String ||
          !RegExp(r'^/hls/[A-Za-z0-9_/-]+$').hasMatch(path) ||
          (domain != 'nicovideo.jp' && domain != '.nicovideo.jp') ||
          entry['secure'] != true ||
          (expires != null && expires is! String) ||
          !keys.add((path, name))) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      DateTime? expiration;
      if (expires is String) {
        try {
          expiration = HttpDate.parse(expires);
        } catch (_) {
          throw const NiconicoException(NiconicoFailure.schema);
        }
      }
      final cookie = Cookie(name, value)
        ..domain = domain as String
        ..path = path
        ..secure = true
        ..expires = expiration;
      final header = cookie.toString();
      final size = uri.origin.length + name.length + value.length + path.length;
      retainedSize += size;
      if (header.length > HlsSessionCookies.maximumCookieCharacters ||
          size > HlsSessionCookies.maximumCookieCharacters ||
          retainedSize > HlsSessionCookies.maximumCharacters) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      headers.add(header);
    }
    final cookies = HlsSessionCookies(now: now)..receive(uri, headers);
    return NiconicoStream._(uri, quality, List<String>.unmodifiable(qualities.cast<String>()), cookies);
  }
}
