import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

enum KilakilaLinkKind { broadcast, owner }

class KilakilaLink {
  const KilakilaLink(this.kind, this.id);
  final KilakilaLinkKind kind;
  final String id;

  // Public website codec constants, not account credentials or app signing
  // secrets. Provenance: official uxin-security-url-crypto-v2.min.js, SHA-256
  // 2a031560d9ccd3770ff57969b8818e5eafd6d8a1e4f54c87e0f4bd983d4607e2.
  static const _readKeys = ['7cdyGRc6Sa93ilPt', 'c98be79a4347bc97'];
  static const _iv = '93x0ue23c2c9h8km';
  static const _signaturePrefix = r'pR@Wv%Wju@Pl&bKc$GyUrPeO';

  static KilakilaLink? parse(String value) {
    if (value.length > 8192) return null;
    final input = value.trim();
    if (RegExp(r'[\x00-\x20\x7f]').hasMatch(input) || RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(input)) {
      return null;
    }
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final roomHost = {'live.kilakila.cn', 'www.hongdoufm.com'}.contains(uri.host);
    final ownerHost = uri.host == 'live.hongrenshuo.com.cn' && uri.scheme == 'https';
    if (!roomHost && !ownerHost) return null;
    // Dart normalizes escaped unreserved path characters. The official codec
    // binds the original route, so do not sign a silently rewritten prefix.
    final rawPath = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]+([^?#]*)').firstMatch(input)?.group(1);
    if (rawPath == null) return null;
    try {
      final query = uri.queryParametersAll;
      if (query.values.any((v) => v.length != 1)) return null;
      final publicOwnerPath = roomHost && rawPath.startsWith('/zhubo/');
      if (publicOwnerPath && uri.hasQuery) return null;
      final pathPrefix = ownerHost ? '/index/roomuser/uid/' : (publicOwnerPath ? '/zhubo/' : '/room/');
      final isPath = rawPath.startsWith(pathPrefix);
      final isDetail = roomHost && {'/PcLive/index/detail', '/PcLive/index/detail/'}.contains(rawPath);
      if (!isPath && !isDetail) return null;
      final kind = ownerHost || publicOwnerPath ? KilakilaLinkKind.owner : KilakilaLinkKind.broadcast;
      String payload;
      if (isPath) {
        if (query.containsKey('id') || query.containsKey('uid') || query.containsKey('_specific_parameter')) {
          return null;
        }
        payload = Uri.decodeComponent(rawPath.substring(pathPrefix.length));
        if (payload.contains('/')) return null;
        if (_validId(payload)) return KilakilaLink(kind, payload);
      } else {
        if (query.containsKey('_specific_parameter')) {
          if (query.containsKey('id') || query.containsKey('sign')) return null;
          payload = query['_specific_parameter']!.single;
        } else {
          final id = query['id']?.single;
          return id != null && _validId(id) ? KilakilaLink(kind, id) : null;
        }
      }
      if (payload.length > 4096 || !RegExp(r'^[A-Za-z0-9_+/\-]+={0,2}$').hasMatch(payload)) {
        return null;
      }
      final bytes = base64Url.decode(base64Url.normalize(payload));
      if (bytes.isEmpty || bytes.length % 16 != 0) return null;
      for (final key in _readKeys) {
        try {
          final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              false,
              PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
                ParametersWithIV(
                  KeyParameter(Uint8List.fromList(utf8.encode(key))),
                  Uint8List.fromList(utf8.encode(_iv)),
                ),
                null,
              ),
            );
          final plain = utf8.decode(cipher.process(bytes));
          final params = _parameters(plain);
          if (params == null) continue;
          final id = params['id'];
          final sign = params['sign'];
          if (id == null || !_validId(id) || sign == null || !RegExp(r'^[a-f0-9]{32}$').hasMatch(sign)) {
            continue;
          }
          var base = '${uri.origin}${isPath ? pathPrefix : '$rawPath?'}';
          String canonical;
          if (isPath && params.length == 2) {
            canonical = id;
          } else {
            if (isPath) base += '$id?';
            final keys = params.keys.where((k) => k != 'sign' && (!isPath || k != 'id')).toList()..sort();
            canonical = keys.map((k) => '$k=${params[k]}').join('&');
          }
          final expected = md5.convert(utf8.encode('$_signaturePrefix$base$canonical')).toString();
          if (expected == sign) return KilakilaLink(kind, id);
        } on ArgumentError {
          continue;
        } on FormatException {
          continue;
        } on InvalidCipherTextException {
          continue;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static bool _validId(String value) => RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(value);

  static Map<String, String>? _parameters(String plain) {
    if (plain.isEmpty || plain.length > 4096 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(plain)) {
      return null;
    }
    final result = <String, String>{};
    final question = plain.indexOf('?');
    var query = plain;
    if (question >= 0) {
      if (plain.indexOf('?', question + 1) >= 0) return null;
      final id = plain.substring(0, question);
      if (!_validId(id)) return null;
      result['id'] = id;
      query = plain.substring(question + 1);
    }
    for (final pair in query.split('&')) {
      final equal = pair.indexOf('=');
      if (equal <= 0 || result.length >= 32) return null;
      var key = pair.substring(0, equal);
      var value = pair.substring(equal + 1);
      // The official codec uses URLSearchParams for ID?query payloads, but
      // preserves raw parameter values for its detail-page query-string form.
      if (question >= 0) {
        key = Uri.decodeQueryComponent(key);
        value = Uri.decodeQueryComponent(value);
      } else if (value.contains('=')) {
        return null;
      }
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$').hasMatch(key) ||
          value.length > 1024 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
          result.containsKey(key)) {
        return null;
      }
      result[key] = value;
    }
    return result;
  }
}
