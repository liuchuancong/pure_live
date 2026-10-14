import 'dart:typed_data';

import 'package:live_sites/src/platforms/acfun/danmaku/acfun_aes.dart';
import 'package:test/test.dart';

/// The bytes of a hex string of the published vectors.
Uint8List _bytes(String hex) =>
    Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);

/// Lowercase hex, so a wrong table reads as a diff against the published value.
String _hex(List<int> bytes) => [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

/// The one plaintext block of the FIPS 197 §C.1 to §C.3 worked examples.
const _plain = '00112233445566778899aabbccddeeff';

/// The FIPS 197 keys and their cipher outputs for that block.
const _key128 = '000102030405060708090a0b0c0d0e0f';
const _key192 = '000102030405060708090a0b0c0d0e0f1011121314151617';
const _key256 = '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
const _cipher128 = '69c4e0d86a7b0430d8cdb78070b4c55a';
const _cipher192 = 'dda97ca4864cdfe06eaf70a0ec0d7191';
const _cipher256 = '8ea2b7ca516745bfeafc49904b496089';

/// SP 800-38A §F.2.1 (CBC-AES128.Encrypt) and §F.2.2 (the same numbers
/// decrypted): four blocks, the reference key and IV of the appendix.
const _cbcKey = '2b7e151628aed2a6abf7158809cf4f3c';
const _cbcIv = '000102030405060708090a0b0c0d0e0f';
const _cbcPlain =
    '6bc1bee22e409f96e93d7e117393172a'
    'ae2d8a571e03ac9c9eb76fac45af8e51'
    '30c81c46a35ce411e5fbc1191a0a52ef'
    'f69f2445df4f9b17ad2b417be66c3710';
const _cbcCipher =
    '7649abac8119b246cee98e9b12e9197d'
    '5086cb9b507219ee95db113a917678b2'
    '73bed6b8e3c1743b7116e69e22229516'
    '3ff1caa1681fac09120eca307586e1a7';

void main() {
  group('FIPS 197 single blocks', () {
    test('AES-128 (C.1)', () {
      expect(_hex(AcfunAesCbc.encryptBlock(_bytes(_plain), key: _bytes(_key128))), _cipher128);
    });

    test('AES-192 (C.2)', () {
      expect(_hex(AcfunAesCbc.encryptBlock(_bytes(_plain), key: _bytes(_key192))), _cipher192);
    });

    test('AES-256 (C.3)', () {
      expect(_hex(AcfunAesCbc.encryptBlock(_bytes(_plain), key: _bytes(_key256))), _cipher256);
    });

    test('AES-128 decrypts its C.1 block back', () {
      // The C.1 block in the CBC form the socket uses: with an all-zero IV the
      // first ciphertext block is exactly the published one, and PKCS#7 always
      // pads, so a whole block of plaintext becomes two blocks of ciphertext.
      // decrypt() reads those two blocks and strips the padding.
      final zeroIv = Uint8List(16);
      final sealed = AcfunAesCbc.encrypt(_bytes(_plain), key: _bytes(_key128), iv: zeroIv);
      expect(sealed.length, 32);
      expect(_hex(sealed.sublist(0, 16)), _cipher128);
      expect(_hex(AcfunAes128Cbc.decrypt(sealed, key: _bytes(_key128), iv: zeroIv)), _plain);
    });
  });

  group('SP 800-38A CBC-AES128', () {
    test('F.2.1 encrypts the four blocks', () {
      // Asserted WITH the PKCS#7 padding encrypt() always adds rather than
      // through the block-level path: chaining is unaffected by a block that
      // follows, so the first 64 bytes are F.2.1's four cipher blocks and the
      // 80-byte output merely appends the encrypted padding block.
      final sealed = AcfunAesCbc.encrypt(_bytes(_cbcPlain), key: _bytes(_cbcKey), iv: _bytes(_cbcIv));
      expect(sealed.length, 80);
      expect(_hex(sealed.sublist(0, 64)), _cbcCipher);
    });

    test('F.2.2 decrypts them again', () {
      expect(
        _hex(AcfunAes128Cbc.decryptBlocks(_bytes(_cbcCipher), key: _bytes(_cbcKey), iv: _bytes(_cbcIv))),
        _cbcPlain,
      );
    });
  });

  group('round trip', () {
    test('encrypt then decrypt returns the plaintext for 0, 1, 16 and 100 bytes', () {
      final key = _bytes(_key128);
      final iv = _bytes(_cbcIv);
      for (final length in [0, 1, 16, 100]) {
        final plain = Uint8List.fromList([for (var i = 0; i < length; i++) i & 0xff]);
        final sealed = AcfunAesCbc.encrypt(plain, key: key, iv: iv);
        // Padding is never omitted: the 16-byte input grows to two blocks.
        expect(sealed.length, (length ~/ 16 + 1) * 16, reason: '$length bytes');
        expect(
          AcfunAes128Cbc.decrypt(sealed, key: key, iv: iv),
          plain,
          reason: '$length bytes',
        );
      }
    });
  });

  group('rejected input', () {
    final key = _bytes(_key128);
    final iv = _bytes(_cbcIv);

    test('a ciphertext that is not whole blocks', () {
      expect(() => AcfunAes128Cbc.decrypt(Uint8List(15), key: key, iv: iv), throwsFormatException);
      expect(() => AcfunAes128Cbc.decrypt(Uint8List(31), key: key, iv: iv), throwsFormatException);
    });

    test('an empty ciphertext', () {
      expect(() => AcfunAes128Cbc.decrypt(Uint8List(0), key: key, iv: iv), throwsFormatException);
    });

    test('a PKCS#7 run that is not the run its last byte claims', () {
      // Eleven plaintext bytes pad with five 0x05 bytes, all inside the one
      // block. In CBC a ciphertext byte only disturbs the plaintext byte at the
      // same position of the same block, so this leaves the length byte 0x05
      // and corrupts the first byte of the run it covers.
      final sealed = Uint8List.fromList(AcfunAesCbc.encrypt(Uint8List(11), key: key, iv: iv));
      sealed[11] ^= 0xff;
      expect(() => AcfunAes128Cbc.decrypt(sealed, key: key, iv: iv), throwsFormatException);
    });

    test('a key or IV that is not 16 bytes for AES-128', () {
      final block = AcfunAesCbc.encrypt(Uint8List(16), key: key, iv: iv);
      expect(() => AcfunAes128Cbc.decrypt(block, key: Uint8List(15), iv: iv), throwsFormatException);
      expect(() => AcfunAes128Cbc.decrypt(block, key: Uint8List(32), iv: iv), throwsFormatException);
      expect(() => AcfunAes128Cbc.decrypt(block, key: key, iv: Uint8List(15)), throwsFormatException);
    });

    test('a key that is not 16, 24 or 32 bytes and an IV or block of the wrong length', () {
      expect(() => AcfunAesCbc.encrypt(Uint8List(4), key: Uint8List(20), iv: iv), throwsFormatException);
      expect(() => AcfunAesCbc.encrypt(Uint8List(4), key: key, iv: Uint8List(15)), throwsFormatException);
      expect(() => AcfunAesCbc.encryptBlock(Uint8List(15), key: key), throwsFormatException);
      expect(() => AcfunAesCbc.encryptBlock(Uint8List(16), key: Uint8List(17)), throwsFormatException);
    });
  });
}
