/// AES-CBC in pure Dart: FIPS 197 (AES) in the SP 800-38A cipher block
/// chaining mode, with PKCS#7 padding.
///
/// Two platform links need this primitive: one seals every WebSocket payload as
/// `IV (16 bytes) || AES-128-CBC(PKCS#7 plaintext)` under a 16-byte key the
/// register exchange hands out ([Aes128Cbc] reads those frames, [AesCbc] writes
/// them), and the other builds an HTTP query parameter as AES-256-CBC over a
/// key and IV derived from a published passphrase ([AesCbc] with a 32-byte key).
///
/// The algorithm is written straight from the standards instead of taken from
/// a package: this package depends on `crypto`, which has hashes and no AES,
/// and a live link does not justify a crypto-primitive dependency. The
/// S-box and its inverse are built at first use from the multiplicative
/// inverse in GF(2^8) and the affine map (FIPS 197 §5.4), so no 256-byte table
/// literal has to be trusted, and the key expansion follows §5.2 for the
/// three key sizes. Nothing here is constant time; it is a framing codec for a
/// public live link, not a secret-key service.
library;

import 'dart:typed_data';

/// The pieces both classes share: the two substitution tables and the
/// arithmetic in GF(2^8) of the AES field (FIPS 197 §4.2, `m(x)` =
/// x^8 + x^4 + x^3 + x + 1).
abstract final class _Aes {
  /// The S-box, built on first use.
  static final Uint8List sbox = _buildSbox();

  /// The inverse S-box, built on first use.
  static final Uint8List inverse = _buildInverse(sbox);

  /// Multiplication by x modulo the field polynomial, the `{02}•` of §5.1.3.
  static int xtime(int value) => ((value << 1) ^ ((value & 0x80) != 0 ? 0x1b : 0)) & 0xff;

  /// The product of [a] and [b] in the field: peasant multiplication with
  /// `xtime` as the doubling.
  static int multiply(int a, int b) {
    var result = 0;
    var x = a;
    var y = b;
    while (y > 0) {
      if ((y & 1) != 0) result ^= x;
      x = xtime(x);
      y >>= 1;
    }
    return result;
  }

  /// The S-box: the GF(2^8) inverse (0 for 0) mapped through the four
  /// rotations of §5.4 and XORed with `0x63`.
  static Uint8List _buildSbox() {
    final box = Uint8List(256);
    for (var value = 0; value < 256; value++) {
      var inverse = 0;
      if (value != 0) {
        for (var candidate = 1; candidate < 256; candidate++) {
          if (multiply(value, candidate) == 1) {
            inverse = candidate;
            break;
          }
        }
      }
      var result = inverse;
      for (var shift = 1; shift <= 4; shift++) {
        result ^= ((inverse << shift) | (inverse >> (8 - shift))) & 0xff;
      }
      box[value] = result ^ 0x63;
    }
    return box;
  }

  /// The inverse table of [box] (§5.3, InvSubBytes).
  static Uint8List _buildInverse(Uint8List box) {
    final inverse = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      inverse[box[i]] = i;
    }
    return inverse;
  }
}

/// AES-128 decryption in the CBC mode of SP 800-38A with PKCS#7 padding
/// (FIPS 197), for a link whose frames are sealed under a 16-byte session key.
/// Encryption, for all three key sizes, is [AesCbc].
abstract final class Aes128Cbc {
  /// Decrypts [data] (whole blocks) with the 16-byte [key] and 16-byte [iv]
  /// and removes the PKCS#7 padding; throws [FormatException] when a length is
  /// wrong or the padding is not the padding.
  static Uint8List decrypt(List<int> data, {required List<int> key, required List<int> iv}) {
    final out = decryptBlocks(data, key: key, iv: iv);
    final pad = out.last;
    if (pad < 1 || pad > 16 || out.sublist(out.length - pad).any((byte) => byte != pad)) {
      throw const FormatException('Bad PKCS#7 padding');
    }
    return Uint8List.sublistView(out, 0, out.length - pad);
  }

  /// Decrypts the whole blocks of [data] without touching the padding.
  static Uint8List decryptBlocks(List<int> data, {required List<int> key, required List<int> iv}) {
    if (key.length != 16 || iv.length != 16) throw const FormatException('AES-128 needs a 16-byte key and IV');
    if (data.isEmpty || data.length % 16 != 0) throw const FormatException('Ciphertext is not whole blocks');
    final rounds = _expand(key);
    final out = Uint8List(data.length);
    // `previous` is the CBC chain: the IV for the first block, then the
    // ciphertext block that was just consumed.
    final previous = Uint8List.fromList(iv);
    final block = Uint8List(16);
    for (var offset = 0; offset < data.length; offset += 16) {
      for (var i = 0; i < 16; i++) {
        block[i] = data[offset + i];
      }
      final plain = _decryptBlock(block, rounds);
      for (var i = 0; i < 16; i++) {
        out[offset + i] = plain[i] ^ previous[i];
        previous[i] = data[offset + i];
      }
    }
    return out;
  }

  /// Key expansion (§5.2, 128-bit key): 11 round keys of 16 bytes.
  static List<Uint8List> _expand(List<int> key) {
    final words = Uint8List(176)..setRange(0, 16, key);
    var rcon = 1;
    for (var i = 16; i < 176; i += 4) {
      var t0 = words[i - 4];
      var t1 = words[i - 3];
      var t2 = words[i - 2];
      var t3 = words[i - 1];
      if (i % 16 == 0) {
        // RotWord, SubWord and the round constant.
        final first = t0;
        t0 = _Aes.sbox[t1] ^ rcon;
        t1 = _Aes.sbox[t2];
        t2 = _Aes.sbox[t3];
        t3 = _Aes.sbox[first];
        rcon = _Aes.xtime(rcon);
      }
      words[i] = words[i - 16] ^ t0;
      words[i + 1] = words[i - 15] ^ t1;
      words[i + 2] = words[i - 14] ^ t2;
      words[i + 3] = words[i - 13] ^ t3;
    }
    return [for (var round = 0; round <= 10; round++) Uint8List.sublistView(words, round * 16, round * 16 + 16)];
  }

  /// The inverse cipher of §5.3 over one [input] block.
  static Uint8List _decryptBlock(Uint8List input, List<Uint8List> rounds) {
    final state = Uint8List.fromList(input);

    void addRoundKey(Uint8List key) {
      for (var i = 0; i < 16; i++) {
        state[i] ^= key[i];
      }
    }

    void inverseShiftAndSub() {
      final copy = Uint8List.fromList(state);
      // Column-major state: byte (row r, column c) is at 4c + r, and row r
      // moves r columns right here (the inverse of ShiftRows) — which is why
      // the source column of a byte is (column + row) % 4.
      for (var column = 0; column < 4; column++) {
        for (var row = 0; row < 4; row++) {
          state[4 * ((column + row) % 4) + row] = _Aes.inverse[copy[4 * column + row]];
        }
      }
    }

    void inverseMixColumns() {
      for (var column = 0; column < 4; column++) {
        final a = state[4 * column];
        final b = state[4 * column + 1];
        final c = state[4 * column + 2];
        final d = state[4 * column + 3];
        state[4 * column] = _Aes.multiply(a, 14) ^ _Aes.multiply(b, 11) ^ _Aes.multiply(c, 13) ^ _Aes.multiply(d, 9);
        state[4 * column + 1] =
            _Aes.multiply(a, 9) ^ _Aes.multiply(b, 14) ^ _Aes.multiply(c, 11) ^ _Aes.multiply(d, 13);
        state[4 * column + 2] =
            _Aes.multiply(a, 13) ^ _Aes.multiply(b, 9) ^ _Aes.multiply(c, 14) ^ _Aes.multiply(d, 11);
        state[4 * column + 3] =
            _Aes.multiply(a, 11) ^ _Aes.multiply(b, 13) ^ _Aes.multiply(c, 9) ^ _Aes.multiply(d, 14);
      }
    }

    addRoundKey(rounds[10]);
    for (var round = 9; round >= 1; round--) {
      inverseShiftAndSub();
      addRoundKey(rounds[round]);
      inverseMixColumns();
    }
    inverseShiftAndSub();
    addRoundKey(rounds[0]);
    return state;
  }
}

/// AES encryption in the CBC mode of SP 800-38A with PKCS#7 padding, for
/// 128-, 192- and 256-bit keys (FIPS 197), for the envelopes a sealed live
/// link is sent with. Decryption of AES-128 is [Aes128Cbc].
abstract final class AesCbc {
  /// Encrypts [plain] after PKCS#7 padding with [key] (16, 24 or 32 bytes) and
  /// [iv] (16 bytes); throws [FormatException] for another length. Padding is
  /// always added, so a whole-block [plain] grows by a full block.
  static Uint8List encrypt(List<int> plain, {required List<int> key, required List<int> iv}) {
    if (iv.length != 16) throw const FormatException('AES-CBC needs a 16-byte IV');
    final rounds = _expand(key);
    final pad = 16 - plain.length % 16;
    final data = Uint8List(plain.length + pad)
      ..setRange(0, plain.length, plain)
      ..fillRange(plain.length, plain.length + pad, pad);
    final chain = Uint8List.fromList(iv);
    for (var offset = 0; offset < data.length; offset += 16) {
      final block = Uint8List.sublistView(data, offset, offset + 16);
      for (var i = 0; i < 16; i++) {
        block[i] ^= chain[i];
      }
      _encryptBlock(block, rounds);
      chain.setRange(0, 16, block);
    }
    return data;
  }

  /// One 16-byte [block] encrypted with [key] (16, 24 or 32 bytes) on its own,
  /// the FIPS 197 vector form of the cipher (§5.1, C.1 to C.3).
  static Uint8List encryptBlock(List<int> block, {required List<int> key}) {
    if (block.length != 16) throw const FormatException('An AES block is 16 bytes');
    return _encryptBlock(Uint8List.fromList(block), _expand(key));
  }

  /// Key expansion (§5.2): rounds + 1 round keys of 16 bytes (11, 13 or 15).
  static List<Uint8List> _expand(List<int> key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw const FormatException('An AES key is 16, 24 or 32 bytes');
    }
    final sbox = _Aes.sbox;
    final words = key.length ~/ 4;
    final rounds = words + 6;
    final bytes = Uint8List(16 * (rounds + 1))..setRange(0, key.length, key);
    var rcon = 1;
    for (var i = words; i < 4 * (rounds + 1); i++) {
      var t0 = bytes[4 * i - 4];
      var t1 = bytes[4 * i - 3];
      var t2 = bytes[4 * i - 2];
      var t3 = bytes[4 * i - 1];
      if (i % words == 0) {
        // RotWord, SubWord and the round constant.
        final first = t0;
        t0 = sbox[t1] ^ rcon;
        t1 = sbox[t2];
        t2 = sbox[t3];
        t3 = sbox[first];
        rcon = _Aes.xtime(rcon);
      } else if (words > 6 && i % words == 4) {
        // The middle substitution AES-256 adds (§5.2, Nk = 8).
        t0 = sbox[t0];
        t1 = sbox[t1];
        t2 = sbox[t2];
        t3 = sbox[t3];
      }
      final previous = 4 * (i - words);
      bytes[4 * i] = bytes[previous] ^ t0;
      bytes[4 * i + 1] = bytes[previous + 1] ^ t1;
      bytes[4 * i + 2] = bytes[previous + 2] ^ t2;
      bytes[4 * i + 3] = bytes[previous + 3] ^ t3;
    }
    return [for (var round = 0; round <= rounds; round++) Uint8List.sublistView(bytes, round * 16, round * 16 + 16)];
  }

  /// The cipher of §5.1 over [state], in place, and returns it.
  static Uint8List _encryptBlock(Uint8List state, List<Uint8List> rounds) {
    final sbox = _Aes.sbox;
    final last = rounds.length - 1;
    final shifted = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      state[i] ^= rounds[0][i];
    }
    for (var round = 1; round <= last; round++) {
      // SubBytes and ShiftRows together. Column-major state: byte (row r,
      // column c) is at 4c + r, and row r moves r columns left — which is why
      // the source column of a byte is (column + row) % 4.
      for (var column = 0; column < 4; column++) {
        for (var row = 0; row < 4; row++) {
          shifted[4 * column + row] = sbox[state[4 * ((column + row) % 4) + row]];
        }
      }
      if (round != last) {
        // MixColumns (§5.1.3), the {02}/{03} matrix written with xtime.
        for (var column = 0; column < 4; column++) {
          final a0 = shifted[4 * column];
          final a1 = shifted[4 * column + 1];
          final a2 = shifted[4 * column + 2];
          final a3 = shifted[4 * column + 3];
          final all = a0 ^ a1 ^ a2 ^ a3;
          shifted[4 * column] = a0 ^ all ^ _Aes.xtime(a0 ^ a1);
          shifted[4 * column + 1] = a1 ^ all ^ _Aes.xtime(a1 ^ a2);
          shifted[4 * column + 2] = a2 ^ all ^ _Aes.xtime(a2 ^ a3);
          shifted[4 * column + 3] = a3 ^ all ^ _Aes.xtime(a3 ^ a0);
        }
      }
      for (var i = 0; i < 16; i++) {
        state[i] = shifted[i] ^ rounds[round][i];
      }
    }
    return state;
  }
}
