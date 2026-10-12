import 'dart:convert';
import 'dart:io' show gzip;

import 'package:live_iptv/src/guide/guide_format/guide_format.dart';
import 'package:live_iptv/src/guide/json_guide_parser/json_guide_parser.dart';
import 'package:live_iptv/src/guide/xmltv_parser/xmltv_parser.dart';
import 'package:live_iptv/src/model/model.dart';

/// Parses guide [text] in [format], detecting it when null.
///
/// A malformed file throws a [FormatException] rather than returning an
/// empty guide: a broken download must not replace a stored one, and only
/// the caller can decide that — an exception it can catch is a decision it
/// can make.
ParsedGuide parseGuide(String text, {GuideFormat? format}) => switch (format ?? GuideFormat.detect(text)) {
  GuideFormat.xmltv => XmltvParser.parse(text),
  GuideFormat.json => JsonGuideParser.parse(text),
};

/// Decodes guide [bytes] as text: gzip when they carry its magic (what most
/// public guides are served as, whatever the packaging URL says) or UTF-8
/// otherwise.
///
/// Throws a [FormatException] for bytes that are neither — a handler that
/// hands back an error page, say — so the caller keeps whatever guide it
/// already had.
String decodeGuideBytes(List<int> bytes) {
  final gzipped = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  return utf8.decode(gzipped ? gzip.decode(bytes) : bytes);
}
