/// Reading a channel list: recognising its shape and parsing it into entries.
///
/// One public unit per folder, as in `src/model/`: the format detection
/// (`playlist_format/`), the two readers (`m3u_parser/`, `txt_parser/`), the
/// dispatcher that picks between them (`playlist_parser/`), and the line
/// shape they share (`playlist_line/`). `playlist_parse_result.dart` stays a
/// file of its own because its two types — the result and one issue — are a
/// pair no reader can use without the other.
///
/// Both readers are tolerant by design: a malformed line drops only itself,
/// never the whole playlist, and what they could not read comes back as
/// `PlaylistIssue`s beside the entries rather than as an exception, because
/// an import has to weigh the two together.
library;

export 'm3u_parser/m3u_parser.dart';
export 'playlist_format/playlist_format.dart';
export 'playlist_line/playlist_line.dart';
export 'playlist_parse_result.dart';
export 'playlist_parser/playlist_parser.dart';
export 'txt_parser/txt_parser.dart';
