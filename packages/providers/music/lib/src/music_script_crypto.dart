// Module: lib/src/music_script_crypto.dart
// Purpose: The Dart side of the lx crypto/zlib bridge endpoints.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: lx-music-desktop preload.js utils.crypto/utils.zlib, backed by Node's
// crypto/zlib there and by pointycastle + dart:io here. The RSA path keeps the
// desktop's exact behaviour: zero-pad the input to the modulus length and raw
// public-encrypt (RSA_NO_PADDING).

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as md5lib;
import 'package:pointycastle/export.dart';

/// Answers one crypto/zlib api call, or null when [api] is not one of these.
/// Throwing inside is fine: the sandbox reports the message to the script.
Future<Object?>? handleMusicScriptCryptoApi(String api, Map<String, Object?> payload) {
  switch (api) {
    case 'crypto.md5':
      return Future.value(md5lib.md5.convert(utf8.encode('${payload['text'] ?? ''}')).toString());
    case 'crypto.randomBytes':
      final size = (payload['size'] as num?)?.toInt() ?? 16;
      if (size < 0 || size > kMaxRandomBytes) {
        // Refused rather than clamped: a script that asked for 1 MiB of key material and silently got 64 KiB
        // would go on to build something wrong out of it, and the wrongness would surface far from here.
        throw FormatException('crypto.randomBytes asks for $size bytes; the ceiling is $kMaxRandomBytes');
      }
      final random = Random.secure();
      return Future.value(base64Encode(List<int>.generate(size, (_) => random.nextInt(256))));
    case 'crypto.aesEncrypt':
      return Future.value(
        base64Encode(
          aesEncrypt(
            base64Decode('${payload['dataB64'] ?? ''}'),
            '${payload['mode'] ?? ''}',
            base64Decode('${payload['keyB64'] ?? ''}'),
            '${payload['ivB64'] ?? ''}'.isEmpty ? null : base64Decode('${payload['ivB64']}'),
          ),
        ),
      );
    case 'crypto.rsaEncrypt':
      return Future.value(
        base64Encode(rsaNoPaddingEncrypt(base64Decode('${payload['dataB64'] ?? ''}'), '${payload['key'] ?? ''}')),
      );
    case 'zlib.inflate':
      return Future.value(base64Encode(zlib.decode(base64Decode('${payload['dataB64'] ?? ''}'))));
    case 'zlib.deflate':
      return Future.value(base64Encode(zlib.encode(base64Decode('${payload['dataB64'] ?? ''}'))));
    default:
      return null;
  }
}

/// The largest `crypto.randomBytes` request this host answers.
const int kMaxRandomBytes = 64 * 1024;

/// AES with PKCS#7 padding over cbc/ecb, keyed by the Node cipher name.
Uint8List aesEncrypt(List<int> data, String mode, List<int> key, List<int>? iv) {
  final nameParts = mode.toLowerCase().split('-');
  if (nameParts.length != 3 || nameParts[0] != 'aes') {
    throw FormatException('unsupported aes mode: $mode');
  }
  final bits = int.parse(nameParts[1]);
  // The mode string is a promise about the key, and the engine would happily take a longer one: asking for
  // aes-128 and handing over 32 bytes used to produce AES-256 output that Node, reading the same request as
  // 128-bit, would never reproduce. The name has to match the material.
  if (key.length * 8 != bits) {
    throw FormatException('$mode asks for a $bits-bit key but got ${key.length * 8} bits');
  }
  final engine = AESEngine()..init(true, KeyParameter(Uint8List.fromList(key)));
  final padded = _padPkcs7(Uint8List.fromList(data), 16);

  Uint8List out;
  if (nameParts[2] == 'ecb') {
    final ecb = ECBBlockCipher(engine);
    out = _processBlocks(ecb, padded);
  } else if (nameParts[2] == 'cbc') {
    if (iv == null || iv.length != 16) {
      throw ArgumentError('cbc mode needs a 16-byte iv');
    }
    final cbc = CBCBlockCipher(engine)
      ..init(true, ParametersWithIV(KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(iv)));
    out = _processBlocks(cbc, padded);
  } else {
    throw FormatException('unsupported aes mode: $mode');
  }
  return out;
}

Uint8List _processBlocks(BlockCipher cipher, Uint8List padded) {
  final blockSize = cipher.blockSize;
  final out = Uint8List(padded.length);
  for (var offset = 0; offset < padded.length; offset += blockSize) {
    cipher.processBlock(padded, offset, out, offset);
  }
  return out;
}

Uint8List _padPkcs7(Uint8List data, int blockSize) {
  final padLength = blockSize - (data.length % blockSize);
  final out = Uint8List(data.length + padLength);
  out.setAll(0, data);
  for (var i = data.length; i < out.length; i++) {
    out[i] = padLength;
  }
  return out;
}

/// Raw RSA public encrypt with zero padding to the modulus length, matching
/// Node's RSA_NO_PADDING path in the desktop preload.
Uint8List rsaNoPaddingEncrypt(List<int> data, String pemKey) {
  final publicKey = _parsePublicKey(pemKey);
  final modulusLength = (publicKey.modulus!.bitLength + 7) ~/ 8;
  if (data.length > modulusLength) {
    throw ArgumentError('rsa input longer than the modulus');
  }
  final padded = Uint8List(modulusLength);
  padded.setAll(modulusLength - data.length, data);
  final engine = RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
  final out = Uint8List(modulusLength);
  final written = engine.processBlock(padded, 0, padded.length, out, 0);
  return Uint8List.fromList(out.sublist(0, written));
}

/// Reads the public key PEM lx sources ship - both PKCS#1 ("BEGIN RSA
/// PUBLIC KEY") and SPKI ("BEGIN PUBLIC KEY") forms - with a minimal DER
/// walk: the only structures these formats need are SEQUENCE, INTEGER and
/// BIT STRING, and hand-rolling those is smaller than a dependency for two
/// shapes.
RSAPublicKey _parsePublicKey(String pem) {
  final base64Body = pem.split(RegExp(r'-----[A-Z ]+-----')).map((part) => part.replaceAll(RegExp(r'\s'), '')).join();
  final reader = _DerReader(base64Decode(base64Body));
  final outer = reader.readSequence();
  final first = outer.readTag();
  if (first == 0x30) {
    // SPKI: SEQUENCE { AlgorithmIdentifier, BIT STRING <PKCS#1> }. The algorithm identifier is skipped by
    // reading *past* it in the outer reader - the previous version descended into its contents and then read
    // the object identifier as if it were the key, so a genuine `BEGIN PUBLIC KEY` failed and the comment's
    // claim to support both forms was false.
    final bitString = outer.readTag();
    if (bitString != 0x03) {
      throw FormatException('SPKI public key has a 0x${bitString.toRadixString(16)} where a BIT STRING belongs');
    }
    final bitContents = outer.lastContent;
    if (bitContents.isEmpty) {
      throw const FormatException('SPKI public key carries an empty BIT STRING');
    }
    // The first byte of a BIT STRING content is the count of unused trailing bits, never part of the key.
    final keyReader = _DerReader(bitContents.sublist(1)).readSequence();
    return RSAPublicKey(keyReader.readInteger(), keyReader.readInteger());
  }
  return RSAPublicKey(outer.readIntegerAt(first), outer.readInteger());
}

final class _DerReader {
  _DerReader(this.bytes);

  final List<int> bytes;
  int _position = 0;
  int _tag = 0;
  List<int> _content = const <int>[];

  /// The content of the last object read.
  List<int> get lastContent => _content;

  int readTag() {
    // Every read below is guarded: `key` arrives as whatever the imported script passed, and a truncated or
    // forged PEM used to escape as a bare RangeError from index arithmetic - an error that names neither the
    // key nor the position, and reads to the caller like a crash in our code rather than bad input.
    if (_position + 2 > bytes.length) {
      throw FormatException('DER object truncated at $_position of ${bytes.length} bytes');
    }
    _tag = bytes[_position++];
    var length = bytes[_position++];
    if (length & 0x80 != 0) {
      final lengthBytes = length & 0x7f;
      if (lengthBytes == 0 || _position + lengthBytes > bytes.length) {
        throw FormatException('DER length header at $_position runs past the buffer');
      }
      length = 0;
      for (var i = 0; i < lengthBytes; i++) {
        length = (length << 8) | bytes[_position++];
      }
    }
    if (length < 0 || _position + length > bytes.length) {
      throw FormatException('DER content of $length bytes does not fit in ${bytes.length - _position} remaining');
    }
    _content = bytes.sublist(_position, _position + length);
    _position += length;
    return _tag;
  }

  BigInt readIntegerAt(int tag) {
    if (tag != 0x02) {
      throw FormatException('expected a DER INTEGER, got 0x${tag.toRadixString(16)}');
    }
    var content = _content;
    if (content.isNotEmpty && content.first == 0x00) {
      content = content.sublist(1);
    }
    var value = BigInt.zero;
    for (final byte in content) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  BigInt readInteger() {
    final tag = readTag();
    return readIntegerAt(tag);
  }

  _DerReader readSequence() {
    final tag = readTag();
    if (tag != 0x30) {
      throw FormatException('expected a DER SEQUENCE, got 0x${tag.toRadixString(16)}');
    }
    return _DerReader(_content);
  }
}
