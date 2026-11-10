import 'dart:convert';
import 'dart:io' show gzip;

import 'package:fast_gbk/fast_gbk.dart';

/// The encodings a list or guide is read with.
enum IptvTextEncoding {
  /// UTF-8, with or without its byte-order mark.
  utf8,

  /// UTF-16, little-endian (the byte-order mark Windows writes).
  utf16le,

  /// UTF-16, big-endian.
  utf16be,

  /// GBK: what a Chinese Windows editor saves as "ANSI", and the encoding a
  /// large share of the hand-made Chinese lists in circulation are in.
  gbk,
}

/// Text read from bytes, with how it was read.
typedef IptvDecodedText = ({String text, IptvTextEncoding encoding, bool gzipped});

const Set<String> _gbkNames = {'gbk', 'gb2312', 'gb18030', 'x-gbk', 'cp936', 'windows-936', 'euc-cn'};

/// Decodes [bytes] as text, whatever the tool that wrote them chose.
///
/// The order is the order of certainty: gzip is inflated first (lists and
/// guides are served compressed under any file name), a byte-order mark
/// is a fact, a [charset] the server declared for GBK is believed, and the
/// rest is tried as strict UTF-8 — which a GBK file with any Chinese in it
/// is not — before GBK reads what UTF-8 refused. Reading a GBK list as UTF-8
/// was the old behaviour, and it imported every Chinese channel name as a
/// row of replacement characters: a list that looked broken, and a guide
/// that matched nothing.
IptvDecodedText decodeIptvText(List<int> bytes, {String? charset}) {
  var data = bytes;
  var gzipped = false;
  if (data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b) {
    data = gzip.decode(data);
    gzipped = true;
  }
  if (data.length >= 3 && data[0] == 0xef && data[1] == 0xbb && data[2] == 0xbf) {
    return (
      text: utf8.decode(data.sublist(3), allowMalformed: true),
      encoding: IptvTextEncoding.utf8,
      gzipped: gzipped,
    );
  }
  if (data.length >= 2 && data[0] == 0xff && data[1] == 0xfe) {
    return (text: _utf16(data, littleEndian: true), encoding: IptvTextEncoding.utf16le, gzipped: gzipped);
  }
  if (data.length >= 2 && data[0] == 0xfe && data[1] == 0xff) {
    return (text: _utf16(data, littleEndian: false), encoding: IptvTextEncoding.utf16be, gzipped: gzipped);
  }
  final declared = charset?.trim().toLowerCase();
  if (declared != null && _gbkNames.contains(declared)) {
    return (text: _gbk(data), encoding: IptvTextEncoding.gbk, gzipped: gzipped);
  }
  try {
    return (text: utf8.decode(data), encoding: IptvTextEncoding.utf8, gzipped: gzipped);
  } on FormatException {
    return (text: _gbk(data), encoding: IptvTextEncoding.gbk, gzipped: gzipped);
  }
}

/// The charset a `content-type` header names, or null.
String? charsetOfContentType(String? contentType) {
  if (contentType == null) {
    return null;
  }
  final match = RegExp(r'charset="?([\w\-]+)', caseSensitive: false).firstMatch(contentType);
  return match?.group(1);
}

String _gbk(List<int> data) => const GbkCodec(allowMalformed: true).decode(data);

/// UTF-16 code units after the two-byte mark, combined by the platform's
/// own surrogate handling.
String _utf16(List<int> data, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 2; i + 1 < data.length; i += 2) {
    units.add(littleEndian ? data[i] | (data[i + 1] << 8) : (data[i] << 8) | data[i + 1]);
  }
  return String.fromCharCodes(units);
}
