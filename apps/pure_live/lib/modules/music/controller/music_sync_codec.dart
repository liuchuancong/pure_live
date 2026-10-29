/// The reference sync protocol's crypto and framing, reduced to what the
/// client side needs: the auth key, AES-128-ECB messages, an RSA pair for
/// first-time auth and the `cg_` gzip frame for oversized sockets payloads.
library;

import 'dart:convert' show base64, base64Decode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' show md5;
import 'package:pointycastle/api.dart'
    show KeyParameter, PaddedBlockCipherParameters, ParametersWithRandom, PrivateKeyParameter, PublicKeyParameter;
import 'package:pointycastle/asymmetric/api.dart' show RSAPrivateKey, RSAPublicKey;
import 'package:pointycastle/asymmetric/oaep.dart' show OAEPEncoding;
import 'package:pointycastle/asymmetric/rsa.dart' show RSAEngine;
import 'package:pointycastle/block/aes.dart' show AESEngine;
import 'package:pointycastle/block/modes/ecb.dart' show ECBBlockCipher;
import 'package:pointycastle/key_generators/api.dart' show RSAKeyGeneratorParameters;
import 'package:pointycastle/key_generators/rsa_key_generator.dart' show RSAKeyGenerator;
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart' show PaddedBlockCipherImpl;
import 'package:pointycastle/paddings/pkcs7.dart' show PKCS7Padding;
import 'package:pointycastle/random/fortuna_random.dart' show FortunaRandom;

/// Derives the 16-character auth key the reference uses: base64 of the auth
/// code's MD5, cut to 16 characters, then read as ASCII bytes for AES.
String musicSyncAuthKey(String authCode) => base64.encode(md5.convert(utf8.encode(authCode)).bytes).substring(0, 16);

/// AES-128-ECB with PKCS7 padding, base64-encoded — the reference's
/// `aesEncrypt`.
String musicSyncAesEncrypt(String text, String key16) =>
    base64.encode(_aes(Uint8List.fromList(utf8.encode(text)), Uint8List.fromList(utf8.encode(key16)), true));

/// The decrypt counterpart; throws when the key is wrong or the payload is
/// not padded ciphertext.
String musicSyncAesDecrypt(String base64Text, String key16) =>
    utf8.decode(_aes(base64Decode(base64Text), Uint8List.fromList(utf8.encode(key16)), false));

Uint8List _aes(Uint8List input, Uint8List key, bool forEncryption) {
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
    ..init(forEncryption, PaddedBlockCipherParameters<KeyParameter, KeyParameter>(KeyParameter(key), KeyParameter(key)));
  return cipher.process(input);
}

/// One half of an RSA-2048 pair, in the DER shapes the reference exchanges:
/// the public key goes out as base64 SPKI (no headers) and the private key
/// stays around as base64 PKCS#8 for the OAEP reply decrypt.
final class MusicSyncRsaKeyPair {
  MusicSyncRsaKeyPair._(this.publicSpkiBase64, this.privatePkcs8Base64, RSAPrivateKey private)
    : _private = private;

  final String publicSpkiBase64;
  final String privatePkcs8Base64;
  final RSAPrivateKey _private;

  /// Generates a fresh pair; used once per code-based auth.
  // ignore: prefer_constructors_over_static_methods
  static MusicSyncRsaKeyPair generate() {
    final secureRandom = FortunaRandom()..seed(KeyParameter(_seed()));
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );
    final pair = generator.generateKeyPair();
    return MusicSyncRsaKeyPair._(
      _spkiBase64(pair.publicKey as RSAPublicKey),
      _pkcs8Base64(pair.privateKey as RSAPrivateKey),
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Decrypts the server's OAEP reply — the auth answer.
  String decryptOaep(String base64Text) {
    final engine = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(_private));
    return utf8.decode(engine.process(base64Decode(base64Text)));
  }

  /// Encrypts with the public half; exercises the OAEP path in tests.
  String encryptOaep(String text) {
    final engine = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(_public));
    return base64.encode(engine.process(Uint8List.fromList(utf8.encode(text))));
  }

  late final RSAPublicKey _public = RSAPublicKey(_private.modulus!, _private.publicExponent!);
}

BigInt _crtDp(RSAPrivateKey key) => key.privateExponent! % (key.p! - BigInt.one);
BigInt _crtDq(RSAPrivateKey key) => key.privateExponent! % (key.q! - BigInt.one);
BigInt _crtQInv(RSAPrivateKey key) => key.q!.modInverse(key.p!);

Uint8List _seed() {
  final seed = Uint8List(32);
  final now = DateTime.now().microsecondsSinceEpoch;
  var state = now & 0xFFFFFFFF;
  for (var i = 0; i < seed.length; i++) {
    state = (state * 1103515245 + 12345) & 0xFFFFFFFF;
    seed[i] = (state >> 16) & 0xFF;
  }
  return seed;
}

// --- Minimal DER encoding; only the two shapes the protocol needs. ---

Uint8List _derLength(int length) {
  if (length < 0x80) return Uint8List.fromList([length]);
  final bytes = <int>[];
  var value = length;
  while (value > 0) {
    bytes.insert(0, value & 0xFF);
    value >>= 8;
  }
  return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
}

Uint8List _der(Uint8List content) => Uint8List.fromList([0x30, ..._derLength(content.length), ...content]);

Uint8List _derInteger(BigInt value) {
  var bytes = _bigIntToBytes(value);
  if (bytes.isEmpty || (bytes[0] & 0x80) != 0) bytes = Uint8List.fromList([0, ...bytes]);
  return Uint8List.fromList([0x02, ..._derLength(bytes.length), ...bytes]);
}

Uint8List _derNullSequence() => Uint8List.fromList([0x30, 0x05, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00]);

Uint8List _derBitString(Uint8List content) {
  final body = [0x00, ...content];
  return Uint8List.fromList([0x03, ..._derLength(body.length), ...body]);
}

Uint8List _derOctetString(Uint8List content) => Uint8List.fromList([0x04, ..._derLength(content.length), ...content]);

Uint8List _bigIntToBytes(BigInt value) {
  final hex = value.toRadixString(16);
  final padded = hex.length.isOdd ? '0$hex' : hex;
  final bytes = <int>[
    for (var i = 0; i < padded.length; i += 2) int.parse(padded.substring(i, i + 2), radix: 16),
  ];
  return Uint8List.fromList(bytes);
}

Uint8List _spkiBody(RSAPublicKey key) => _der(Uint8List.fromList([
      ..._derInteger(key.modulus!),
      ..._derInteger(key.exponent!),
    ]));

String _spkiBase64(RSAPublicKey key) => base64.encode(
      Uint8List.fromList([
        ..._derNullSequence(),
        ..._derBitString(_spkiBody(key)),
      ]),
    );

String _pkcs8Base64(RSAPrivateKey key) {
  final rsaPrivate = _der(Uint8List.fromList([
    ..._derInteger(BigInt.zero),
    ..._derInteger(key.modulus!),
    ..._derInteger(key.publicExponent!),
    ..._derInteger(key.privateExponent!),
    ..._derInteger(key.p!),
    ..._derInteger(key.q!),
    ..._derInteger(_crtDp(key)),
    ..._derInteger(_crtDq(key)),
    ..._derInteger(_crtQInv(key)),
  ]));
  final algorithm = _derNullSequence();
  final pkcs8 = _der(Uint8List.fromList([
    ..._derInteger(BigInt.zero),
    ...algorithm,
    ..._derOctetString(rsaPrivate),
  ]));
  return base64.encode(pkcs8);
}
