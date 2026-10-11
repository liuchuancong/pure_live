import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as c;
import 'package:live_sites/live_sites.dart';

/// Static parsers and the token codec for the Bigo Live web APIs.
abstract final class BigoParser {
  /// Studio API host.
  static const String apiHost = 'ta.bigo.tv';

  /// Token API host.
  static const String tokenHost = 'sec.bigo.sg';

  /// Web origin.
  static const String origin = 'https://www.bigo.tv';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': origin,
    'referer': '$origin/',
  };

  /// Media headers of stream [siteId].
  static Map<String, String> mediaHeaders(String siteId) => {
    'user-agent': headers['user-agent']!,
    'origin': origin,
    'referer': '$origin/$siteId',
  };

  /// A random JSONP callback name.
  static String callback() {
    final random = Random.secure();
    return 'jsonp${[for (var i = 0; i < 16; i++) random.nextInt(36).toRadixString(36)].join()}';
  }

  /// Unwraps a JSONP body of [callback] into its JSON object.
  static Map<String, Object?> jsonp(String body, {required String callback, int status = 200, String what = 'jsonp'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('bigo $what: HTTP $status');
    }
    final start = body.indexOf('(');
    final end = body.lastIndexOf(')');
    if (start < 0 || end <= start) {
      throw SiteApiChangedError('bigo $what: not JSONP');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body.substring(start + 1, end));
    } on FormatException {
      throw SiteApiChangedError('bigo $what: payload is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('bigo $what: payload is not an object');
    }
    return decoded;
  }

  /// `webjs/t` → the server time (1-20 digits).
  static String serverTime(String body, {required String callback, int status = 200}) {
    final value = jsonp(body, callback: callback, status: status, what: 'webjs/t')['time']?.toString() ?? '';
    if (!RegExp(r'^\d{1,20}$').hasMatch(value)) {
      throw const SiteApiChangedError('bigo webjs/t: no server time');
    }
    return value;
  }

  /// `webjs/status` → the web token.
  static String token(String body, {required String callback, int status = 200}) {
    final value = jsonp(body, callback: callback, status: status, what: 'webjs/status')['token']?.toString() ?? '';
    if (value.isEmpty || value.length > 4096 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) {
      throw const SiteApiChangedError('bigo webjs/status: no usable token');
    }
    return value;
  }

  static const String _passphrase = 'undefinedval0x01';

  /// The `data` of the token request for [timestamp]: OpenSSL's `Salted__`
  /// + 8-byte salt + AES-256-CBC, key and IV from EVP_BytesToKey (md5, one
  /// round) over the published passphrase, Base64.
  static Future<String> tokenData(String timestamp, {Random? random}) async {
    final generator = random ?? Random.secure();
    final salt = [for (var i = 0; i < 8; i++) generator.nextInt(256)];
    final dr = [for (var i = 0; i < 32; i++) generator.nextInt(16).toRadixString(16)].join();
    final payload = utf8.encode(
      jsonEncode({'dr': dr, 'business': 'bigolive-video', 'scene': '', 'at_time': timestamp, 'ver': '2.0'}),
    );
    final derived = _evpBytesToKey(utf8.encode(_passphrase), salt, 48);
    final box = await _aes.encrypt(
      payload,
      secretKey: c.SecretKey(Uint8List.sublistView(derived, 0, 32)),
      nonce: Uint8List.sublistView(derived, 32, 48),
    );
    return base64Encode([...ascii.encode('Salted__'), ...salt, ...box.cipherText]);
  }

  static final c.AesCbc _aes = c.AesCbc.with256bits(macAlgorithm: c.MacAlgorithm.empty);

  /// EVP_BytesToKey with md5, one round: md5(pass + salt), extended by
  /// hashing the previous block + pass + salt until [length] bytes.
  static Uint8List _evpBytesToKey(List<int> passphrase, List<int> salt, int length) {
    final out = BytesBuilder();
    var previous = const <int>[];
    while (out.length < length) {
      previous = crypto.md5.convert([...previous, ...passphrase, ...salt]).bytes;
      out.add(previous);
    }
    return Uint8List.fromList(out.takeBytes().sublist(0, length));
  }

  /// `getInternalStudioInfo` → the studio facts and its HLS playlist.
  static ({
    String siteId,
    bool alive,
    bool needsLogin,
    bool password,
    bool paid,
    String? title,
    String? nick,
    String? avatar,
    String? cover,
    String? area,
    String? hls,
  })
  studio(String body, {required String requestedSiteId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('bigo getInternalStudioInfo: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('bigo getInternalStudioInfo: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('bigo getInternalStudioInfo: body is not an object');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('bigo getInternalStudioInfo: no data');
    }
    if (data['uid'] == null && data['clientBigoId'] == null) {
      throw SiteNotFoundError('bigo: no studio for "$requestedSiteId"');
    }
    final needsLogin = data['needLogin'] == true;
    final password = data['passRoom'] == true;
    final paid = data['isPaidShow']?.toString() == '1';
    final alive = data['alive'] == '1' || data['alive'] == 1 || data['alive'] == true;
    final hls = data['hls_src']?.toString() ?? '';
    return (
      siteId: data['clientBigoId']?.toString() ?? requestedSiteId,
      alive: alive,
      needsLogin: needsLogin,
      password: password,
      paid: paid,
      title: data['roomTopic']?.toString(),
      nick: data['nick_name']?.toString(),
      avatar: _image(data['avatar']),
      cover: _image(data['snapshot']),
      area: data['gameTitle']?.toString(),
      hls: (!needsLogin && !password && !paid && alive && hls.startsWith('http')) ? hls : null,
    );
  }

  /// The room snapshot of a studio.
  static LiveRoom room(
    ({
      String siteId,
      bool alive,
      bool needsLogin,
      bool password,
      bool paid,
      String? title,
      String? nick,
      String? avatar,
      String? cover,
      String? area,
      String? hls,
    })
    studio,
  ) => LiveRoom(
    platform: SiteIds.bigo,
    roomId: studio.siteId,
    title: studio.title ?? studio.nick ?? '',
    nick: studio.nick ?? '',
    avatar: studio.avatar,
    cover: studio.cover,
    areaName: studio.area,
    status: studio.alive ? LiveStatus.live : LiveStatus.offline,
    restriction: switch (studio) {
      _ when studio.needsLogin => LiveRestriction.needsLogin,
      _ when studio.password => LiveRestriction.password,
      _ when studio.paid => LiveRestriction.paid,
      _ => null,
    },
    data: studio.hls,
  );

  /// The play line of a studio's HLS playlist.
  static LivePlayLine line(String hls, String siteId) =>
      LivePlayLine(url: hls, headers: mediaHeaders(siteId), format: StreamFormat.hls, codec: 'avc', lineId: 'hls');

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
