import 'dart:convert' show utf8;

import 'package:live_iptv/src/guide/guide_parser/guide_parser.dart';
import 'package:live_iptv/src/guide/json_guide_parser/json_guide_parser.dart';
import 'package:live_iptv/src/guide/xmltv_parser/xmltv_parser.dart';
import 'package:test/test.dart';

/// The guide ceilings: a file past the programme count is refused mid-parse
/// rather than built and then measured, and a decoded body past the text
/// ceiling is refused before any parser sees it. The limits are parameters
/// here so the tests stay off the production numbers.
void main() {
  const row =
      '<programme channel="c" start="20261112000000 +0800" stop="20261112010000 +0800"> '
      '<title>news</title></programme>';

  test('xmltv past the programme ceiling is refused mid-parse', () {
    final xml = '<tv>${row * 6}</tv>';
    expect(() => XmltvParser.parse(xml, programmeLimit: 5), throwsFormatException);
    // Under the ceiling the same rows parse untouched.
    expect(XmltvParser.parse('<tv>$row</tv>', programmeLimit: 5).programmes, hasLength(1));
  });

  test('json past the programme ceiling is refused', () {
    const jsonRow = '{"channel":"c","title":"news","start":1762900000}';
    const json = '{"programmes":[$jsonRow,$jsonRow,$jsonRow,$jsonRow]}';
    expect(() => JsonGuideParser.parse(json, programmeLimit: 3), throwsFormatException);
    expect(JsonGuideParser.parse('{"programmes":[$jsonRow]}', programmeLimit: 3).programmes, hasLength(1));
  });

  test('decoded text past the ceiling is refused before parsing', () {
    expect(() => decodeGuideBytes(utf8.encode('x' * 64), textCharLimit: 8), throwsFormatException);
    expect(decodeGuideBytes(utf8.encode('x' * 8), textCharLimit: 8), 'x' * 8);
  });
}
