import 'package:live_iptv/src/guide/guide_format/guide_format.dart';
import 'package:live_iptv/src/guide/json_guide_parser/json_guide_parser.dart';
import 'package:live_iptv/src/guide/xmltv_parser/xmltv_parser.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/text_decode/text_decode.dart';

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
/// public guides are served as, whatever the packaging URL says), then the
/// byte-order mark, UTF-8, and GBK for the guides a Chinese editor saved
/// ([decodeIptvText]).
///
/// Throws a [FormatException] for compressed bytes that do not inflate; text
/// that is not a guide fails in [parseGuide], so the caller keeps whatever
/// guide it already had either way.
String decodeGuideBytes(List<int> bytes) => decodeIptvText(bytes).text;
