import 'dart:math';
import 'package:crypto/crypto.dart';

const String xbogusAlphabet =
    'Dkdpgh4ZKsQB80/Mfvw36XI1R25+WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe';

const String standardAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

const List<int> emptyMd5Bytes = [0x45, 0x3f];

final List<int> alphabetLookup = (() {
  final table = List<int>.filled(128, 0);
  for (int i = 0; i < 64; i++) {
    table[standardAlphabet.codeUnitAt(i)] =
        xbogusAlphabet.codeUnitAt(i);
  }
  return table;
})();

/// RC4
void rc4Encrypt(int key, List<int> data) {
  final s = List<int>.generate(256, (i) => i);

  int j = 0;

  for (int i = 0; i < 256; i++) {
    j = (j + s[i] + key) & 0xff;
    final tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
  }

  int ii = 0;
  j = 0;

  for (int k = 0; k < data.length; k++) {
    ii = (ii + 1) & 0xff;
    j = (j + s[ii]) & 0xff;

    final tmp = s[ii];
    s[ii] = s[j];
    s[j] = tmp;

    data[k] ^= s[(s[ii] + s[j]) & 0xff];
  }
}

/// Base64编码并映射到X-Bogus字符表
String encodeBase64(List<int> data) {
  final out = StringBuffer();

  for (int i = 0; i < data.length; i += 3) {
    final b0 = data[i];
    final b1 = data[i + 1];
    final b2 = data[i + 2];

    out.writeCharCode(
        alphabetLookup[standardAlphabet.codeUnitAt((b0 >> 2) & 0x3f)]);

    out.writeCharCode(
        alphabetLookup[standardAlphabet.codeUnitAt(((b0 << 4) | (b1 >> 4)) & 0x3f)]);

    out.writeCharCode(
        alphabetLookup[standardAlphabet.codeUnitAt(((b1 << 2) | (b2 >> 6)) & 0x3f)]);

    out.writeCharCode(
        alphabetLookup[standardAlphabet.codeUnitAt(b2 & 0x3f)]);
  }

  return out.toString();
}

int hexByte(String hex) {
  return int.parse(hex, radix: 16);
}

/// md5(decode(hexString)) 最后两个字节
List<int> md5Last2(String hexStr) {
  final bytes = List<int>.generate(
    16,
        (i) => hexByte(hexStr.substring(i * 2, i * 2 + 2)),
  );

  final digest = md5.convert(bytes).bytes;

  return [digest[14], digest[15]];
}

/// 生成 X-Bogus
String generateXBogus(
    String msStub,
    int counter,
    ) {
  if (msStub.length != 32) {
    throw ArgumentError('msStub must be 32-char md5 hex string');
  }

  final random = Random.secure();

  final random1 = random.nextInt(256);
  final random2 = random.nextInt(255);

  final header = 0x40 | (random1 & 0x1f);

  final md5Bytes = md5Last2(msStub);

  final payload = <int>[
    counter & 0x3f,
    0,
    1,
    0x0e,
    emptyMd5Bytes[0],
    emptyMd5Bytes[1],
    md5Bytes[0],
    md5Bytes[1],
    random2,
    0,
  ];

  int checksum = 0;
  for (int i = 0; i < 9; i++) {
    checksum ^= payload[i];
  }

  payload[9] = checksum;

  rc4Encrypt(random2, payload);

  final finalData = List<int>.filled(12, 0);

  finalData[0] = header;
  finalData[1] = random2;

  for (int i = 0; i < 10; i++) {
    finalData[i + 2] = payload[i];
  }

  return encodeBase64(finalData);
}