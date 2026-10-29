import 'dart:convert' show base64, jsonEncode, utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' show md5;
import 'package:pointycastle/export.dart';

const String _iv = '0102030405060708';
const String _presetKey = '0CoJUm6Qyw8W8jud';
const String _eapiKey = 'e82ckenh8dichen8';
const String _base62 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

// Netease's fixed public key (the reference's `publicKey`), reduced to its
// modulus and exponent.
final BigInt _rsaModulus = BigInt.parse(
  'e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf'
  '695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d5'
  '46b8e289dc6935b3ece0462db0a22b8e7',
  radix: 16,
);
final BigInt _rsaExponent = BigInt.from(65537);

Uint8List _aesCbc(List<int> data, List<int> key) {
  final cipher = PaddedBlockCipher('PKCS7/AES/CBC')
    ..init(
      true,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(_iv.codeUnits)),
        null,
      ),
    );
  return cipher.process(Uint8List.fromList(data));
}

Uint8List _aesEcb(List<int> data, List<int> key) {
  final cipher = PaddedBlockCipher('PKCS7/AES/ECB')
    ..init(true, PaddedBlockCipherParameters(KeyParameter(Uint8List.fromList(key)), null));
  return cipher.process(Uint8List.fromList(data));
}

Uint8List _rsaNoPadding(List<int> block) {
  final engine = RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(RSAPublicKey(_rsaModulus, _rsaExponent)));
  final input = Uint8List(128)..setAll(128 - block.length, block);
  return engine.process(input);
}

/// Netease's `weapi` form: the payload is AES-CBC'd twice (the second round
/// with a random key that RSA carries alongside it).
(Map<String, String>, String) weapi(Object object) {
  final text = jsonEncode(object);
  final secret = Uint8List.fromList([for (var i = 0; i < 16; i++) _base62.codeUnitAt(Random.secure().nextInt(62))]);
  final first = _aesCbc(utf8.encode(text), _presetKey.codeUnits);
  final params = base64.encode(_aesCbc(base64.encode(first).codeUnits, secret));
  final encSecKey = _rsaNoPadding(secret.reversed.toList())
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return ({'params': params, 'encSecKey': encSecKey}, text);
}

/// Netease's `eapi` form: the URL, payload and an MD5 digest ride one
/// AES-ECB-encrypted string as the `params` field.
Map<String, String> eapi(String url, Object object) {
  final text = jsonEncode(object);
  final digest = md5.convert(utf8.encode('nobody${url}use${text}md5forencrypt')).toString();
  final data = '$url-36cd479b6b5-$text-36cd479b6b5-$digest';
  final params = _aesEcb(
    utf8.encode(data),
    _eapiKey.codeUnits,
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return {'params': params};
}
