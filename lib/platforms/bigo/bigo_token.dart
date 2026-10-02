import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// Reproduces the current public Bigo web token envelope. The passphrase is a
/// website protocol constant used by the browser bundle, not account material.
final class BigoTokenCodec {
  const BigoTokenCodec._();

  static const _passphrase = 'undefinedval0x01';

  static String buildData(String timestamp, {Uint8List? salt, String? randomHex}) {
    if (!RegExp(r'^[0-9]{1,20}$').hasMatch(timestamp)) {
      throw const FormatException('Invalid Bigo token timestamp');
    }
    final random = Random.secure();
    final actualSalt = salt ?? Uint8List.fromList(List<int>.generate(8, (_) => random.nextInt(256)));
    if (actualSalt.length != 8) throw const FormatException('Invalid Bigo token salt');
    final dr = randomHex ?? List<String>.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(dr)) throw const FormatException('Invalid Bigo token nonce');
    final payload = utf8.encode(
      jsonEncode(<String, String>{
        'dr': dr,
        'business': 'bigolive-video',
        'scene': '',
        'at_time': timestamp,
        'ver': '2.0',
      }),
    );
    final (key, iv) = _evpBytesToKey(
      Uint8List.fromList(utf8.encode(_passphrase)),
      Uint8List.fromList(actualSalt),
      keyLength: 32,
      ivLength: 16,
    );
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    final encrypted = cipher.process(Uint8List.fromList(payload));
    return base64Encode(<int>[...ascii.encode('Salted__'), ...actualSalt, ...encrypted]);
  }

  static (Uint8List, Uint8List) _evpBytesToKey(
    Uint8List password,
    Uint8List salt, {
    required int keyLength,
    required int ivLength,
  }) {
    final output = BytesBuilder(copy: false);
    Uint8List previous = Uint8List(0);
    while (output.length < keyLength + ivLength) {
      previous = Uint8List.fromList(md5.convert(<int>[...previous, ...password, ...salt]).bytes);
      output.add(previous);
    }
    final bytes = output.takeBytes();
    return (Uint8List.sublistView(bytes, 0, keyLength), Uint8List.sublistView(bytes, keyLength, keyLength + ivLength));
  }
}
