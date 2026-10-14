import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_json.dart';

/// Bigo's anonymous web token: the JSONP callback name, the encrypted request
/// body of `webjs/status` and the reading of the two token answers.
///
/// Every studio read is asked with a token (`getInternalStudioInfo?token=…`),
/// and only a token's *first* use answers with the media playlist and says
/// whether the room has a password. A token is made with two requests to
/// `sec.bigo.sg`: `webjs/t` gives the server time, and `webjs/status` the token
/// for [tokenData] of that time — AES-256-CBC of a small JSON payload under a
/// key and IV derived from the website's published passphrase the way OpenSSL's
/// `EVP_BytesToKey` (md5, one round) does, wrapped as `Salted__` + salt +
/// ciphertext and Base64-ed. Both answers come back as JSONP of the callback
/// name sent with the request, so the callback is checked as strictly as the
/// payload.
abstract final class BigoToken {
  /// The website's published passphrase, the password half of the key
  /// derivation.
  static const String passphrase = 'undefinedval0x01';

  /// The token endpoints answer JSONP of the callback sent with the request.
  static const String what = 'webjs';

  static final RegExp _digits = RegExp(r'^[0-9]{1,20}$');
  static final RegExp _callback = RegExp(r'^jsonp[A-Za-z0-9_]{1,96}$');
  static final RegExp _nonce = RegExp(r'^[a-f0-9]{32}$');

  /// The JSONP callback name of a request made at [now] (the page's own
  /// `jsonpcallback_<milliseconds>_<microseconds>`).
  static String callbackName(DateTime now) =>
      'jsonpcallback_${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000000}';

  /// Whether [name] is a callback name the token service is asked with.
  static bool isCallbackName(String name) => _callback.hasMatch(name);

  /// `webjs/t`: the server time the token request is made for, as written (a
  /// fixed value, not the clock). The answer is JSONP of [callback]; `code`
  /// must be a number and `time` 1–20 digits.
  static String serverTime(String body, {required String callback, required int status}) {
    final answer = jsonpObject(body, callback: callback, status: status, what: 'webjs/t');
    if (answer['code'] is! int) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'webjs/t: code is ${answer['code']}');
    }
    final time = answer['time'];
    if (time is! String || !_digits.hasMatch(time)) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'webjs/t: time is $time');
    }
    return time;
  }

  /// `webjs/status`: the web token out of the JSONP answer of [callback]:
  /// non-empty, at most 4096 characters, without spaces or control characters.
  static String token(String body, {required String callback, required int status}) {
    final value = jsonpObject(body, callback: callback, status: status, what: 'webjs/status')['token'];
    if (value is! String || value.isEmpty || value.length > 4096 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) {
      throw const BigoFailure(BigoFailureKind.apiChanged, 'webjs/status: no usable token');
    }
    return value;
  }

  /// The `data` of the token request for the server [timestamp]: the JSON
  /// payload of [nonce] (32 lower-case hex digits, the page's `dr`) and [salt]
  /// (8 bytes) — both drawn from [random] unless given — sealed as `Salted__` +
  /// salt + AES-256-CBC(payload), Base64-ed.
  static String tokenData(String timestamp, {Random? random, List<int>? salt, String? nonce}) {
    if (!_digits.hasMatch(timestamp)) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'webjs/t: timestamp "$timestamp" is not 1–20 digits');
    }
    final generator = random ?? Random.secure();
    final actualSalt = salt ?? [for (var i = 0; i < 8; i++) generator.nextInt(256)];
    if (actualSalt.length != 8) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'token request: salt is ${actualSalt.length} bytes');
    }
    final dr = nonce ?? [for (var i = 0; i < 32; i++) generator.nextInt(16).toRadixString(16)].join();
    if (!_nonce.hasMatch(dr)) {
      throw const BigoFailure(BigoFailureKind.apiChanged, 'token request: the nonce is not 32 hex digits');
    }
    final payload = utf8.encode(
      jsonEncode({'dr': dr, 'business': 'bigolive-video', 'scene': '', 'at_time': timestamp, 'ver': '2.0'}),
    );
    final derived = evpBytesToKey(utf8.encode(passphrase), actualSalt, 48);
    final encrypted = AesCbc.encrypt(
      payload,
      key: Uint8List.sublistView(derived, 0, 32),
      iv: Uint8List.sublistView(derived, 32, 48),
    );
    return base64Encode([...ascii.encode('Salted__'), ...actualSalt, ...encrypted]);
  }

  /// OpenSSL's `EVP_BytesToKey` with md5 and one round: `D_i = md5(D_{i-1} +
  /// password + salt)`, the blocks concatenated and cut to [length] bytes — the
  /// first 32 the AES-256 key, the last 16 the IV.
  static Uint8List evpBytesToKey(List<int> password, List<int> salt, int length) {
    final output = BytesBuilder(copy: false);
    var previous = <int>[];
    while (output.length < length) {
      previous = md5.convert([...previous, ...password, ...salt]).bytes;
      output.add(previous);
    }
    return Uint8List.sublistView(output.takeBytes(), 0, length);
  }
}
