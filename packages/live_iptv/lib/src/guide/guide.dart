/// Reading a programme guide: recognising its shape, parsing it, and finding
/// the guide channel a playlist line refers to.
///
/// One public unit per folder, as in `src/model/`: the format detection
/// (`guide_format/`), the two parsers (`xmltv_parser/`,
/// `json_guide_parser/`), the dispatcher that picks between them and decodes
/// the bytes (`guide_parser/`), the in-memory guide a player asks questions
/// of (`epg_guide/`), and the reader that fills it, from text in hand or
/// over the wire (`epg_parser/`). The matcher is still one file,
/// `guide_matcher.dart`: its steps share a private normalisation, so it is
/// one algorithm rather than several units living together.
library;

export 'epg_guide/epg_guide.dart';
export 'epg_parser/epg_parser.dart';
export 'guide_format/guide_format.dart';
export 'guide_matcher.dart';
export 'guide_parser/guide_parser.dart';
export 'json_guide_parser/json_guide_parser.dart';
export 'xmltv_parser/xmltv_parser.dart';
