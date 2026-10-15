import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a KilaKila link names.
enum KilakilaLinkKind {
  /// One broadcast (`roomIdStr`), new every time the anchor goes live; its
  /// anchor is found with `getRoomInfo`.
  broadcast,

  /// An anchor's uid: the room identity.
  owner,
}

/// A KilaKila link: an anchor page, or a broadcast page whose id may be
/// sealed in the website's encrypted share parameter.
@immutable
final class KilakilaLink {
  /// Creates a link.
  const KilakilaLink(this.kind, this.id);

  /// Broadcast or anchor.
  final KilakilaLinkKind kind;

  /// The broadcast id or the uid.
  final String id;

  // Public constants of the website's codec (uxin-security-url-crypto-v2.min.js,
  // SHA-256 2a031560d9ccd3770ff57969b8818e5eafd6d8a1e4f54c87e0f4bd983d4607e2),
  // not credentials.
  static const List<String> _readKeys = ['7cdyGRc6Sa93ilPt', 'c98be79a4347bc97'];
  static const String _iv = '93x0ue23c2c9h8km';
  static const String _signaturePrefix = r'pR@Wv%Wju@Pl&bKc$GyUrPeO';

  static final RegExp _unsafe = RegExp(r'[\x00-\x20\x7f]');
  static final RegExp _badEscape = RegExp('%(?![0-9a-fA-F]{2})');
  static final RegExp _rawPath = RegExp('^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]+([^?#]*)');
  static final RegExp _payload = RegExp(r'^[A-Za-z0-9_+/\-]+={0,2}$');
  static final RegExp _sign = RegExp(r'^[a-f0-9]{32}$');
  static final RegExp _key = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$');

  /// The link [value] is, exactly as the reference read it, or null:
  /// - `live.kilakila.cn` or `www.hongdoufm.com` (http or https, default
  ///   port): `/room/<id>` and `/PcLive/index/detail?id=<id>` name a
  ///   broadcast, `/zhubo/<uid>` (no query) an anchor;
  /// - `https://live.hongrenshuo.com.cn/index/roomuser/uid/<uid>` names an
  ///   anchor;
  /// - instead of the id, a room or anchor path may carry an encrypted
  ///   payload and a detail page `_specific_parameter`: URL-safe base64,
  ///   AES-128-CBC with one of the public keys, whose plaintext holds the id
  ///   and an MD5 `sign` over the scheme, host and route as written. A
  ///   payload that does not decrypt or whose signature does not match
  ///   (another host, a re-encoded route) is no link.
  ///
  /// Whitespace, control characters, broken `%` escapes, user info, a
  /// fragment, repeated parameters or an id with a leading zero make it no
  /// link. The value is one URL, not a share text.
  static KilakilaLink? parse(String value) {
    if (value.length > 8192) return null;
    final input = value.trim();
    if (_unsafe.hasMatch(input) || _badEscape.hasMatch(input)) return null;
    final uri = Uri.tryParse(input);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final roomHost = KilakilaEndpoints.roomHosts.contains(uri.host);
    final ownerHost = uri.host == KilakilaEndpoints.ownerHost && uri.scheme == 'https';
    if (!roomHost && !ownerHost) return null;
    // Dart normalizes escaped unreserved path characters, but the signature
    // binds the route as written: read it from the input.
    final rawPath = _rawPath.firstMatch(input)?.group(1);
    if (rawPath == null) return null;
    try {
      final query = uri.queryParametersAll;
      if (query.values.any((values) => values.length != 1)) return null;
      final publicOwnerPath = roomHost && rawPath.startsWith('/zhubo/');
      if (publicOwnerPath && uri.hasQuery) return null;
      final pathPrefix = ownerHost ? '/index/roomuser/uid/' : (publicOwnerPath ? '/zhubo/' : '/room/');
      final isPath = rawPath.startsWith(pathPrefix);
      final isDetail = roomHost && (rawPath == '/PcLive/index/detail' || rawPath == '/PcLive/index/detail/');
      if (!isPath && !isDetail) return null;
      final kind = ownerHost || publicOwnerPath ? KilakilaLinkKind.owner : KilakilaLinkKind.broadcast;
      String payload;
      if (isPath) {
        if (query.containsKey('id') || query.containsKey('uid') || query.containsKey('_specific_parameter')) {
          return null;
        }
        payload = Uri.decodeComponent(rawPath.substring(pathPrefix.length));
        if (payload.contains('/')) return null;
        if (KilakilaEndpoints.isId(payload)) return KilakilaLink(kind, payload);
      } else {
        if (query.containsKey('_specific_parameter')) {
          if (query.containsKey('id') || query.containsKey('sign')) return null;
          payload = query['_specific_parameter']!.single;
        } else {
          final id = query['id']?.single;
          return id != null && KilakilaEndpoints.isId(id) ? KilakilaLink(kind, id) : null;
        }
      }
      if (payload.length > 4096 || !_payload.hasMatch(payload)) return null;
      final bytes = base64Url.decode(base64Url.normalize(payload));
      if (bytes.isEmpty || bytes.length % 16 != 0) return null;
      for (final key in _readKeys) {
        try {
          final plain = utf8.decode(Aes128Cbc.decrypt(bytes, key: utf8.encode(key), iv: utf8.encode(_iv)));
          final params = _parameters(plain);
          if (params == null) continue;
          final id = params['id'];
          final sign = params['sign'];
          if (id == null || !KilakilaEndpoints.isId(id) || sign == null || !_sign.hasMatch(sign)) continue;
          var base = '${uri.origin}${isPath ? pathPrefix : '$rawPath?'}';
          String canonical;
          if (isPath && params.length == 2) {
            canonical = id;
          } else {
            if (isPath) base += '$id?';
            final keys = params.keys.where((key) => key != 'sign' && (!isPath || key != 'id')).toList()..sort();
            canonical = keys.map((key) => '$key=${params[key]}').join('&');
          }
          if (_md5('$_signaturePrefix$base$canonical') == sign) {
            return KilakilaLink(kind, id);
          }
        } on FormatException {
          continue;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static String _md5(String value) => crypto.md5.convert(utf8.encode(value)).toString();

  /// The parameters of a decrypted payload: `<id>?k=v&…` (URL-encoded, the
  /// website's URLSearchParams) for paths, `k=v&…` (raw values) for the
  /// detail page; null when malformed.
  static Map<String, String>? _parameters(String plain) {
    if (plain.isEmpty || plain.length > 4096 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(plain)) return null;
    final result = <String, String>{};
    final question = plain.indexOf('?');
    var query = plain;
    if (question >= 0) {
      if (plain.indexOf('?', question + 1) >= 0) return null;
      final id = plain.substring(0, question);
      if (!KilakilaEndpoints.isId(id)) return null;
      result['id'] = id;
      query = plain.substring(question + 1);
    }
    for (final pair in query.split('&')) {
      final equal = pair.indexOf('=');
      if (equal <= 0 || result.length >= 32) return null;
      var key = pair.substring(0, equal);
      var value = pair.substring(equal + 1);
      if (question >= 0) {
        key = Uri.decodeQueryComponent(key);
        value = Uri.decodeQueryComponent(value);
      } else if (value.contains('=')) {
        return null;
      }
      if (!_key.hasMatch(key) ||
          value.length > 1024 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
          result.containsKey(key)) {
        return null;
      }
      result[key] = value;
    }
    return result;
  }

  @override
  bool operator ==(Object other) => other is KilakilaLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'KilakilaLink(${kind.name}, $id)';
}
