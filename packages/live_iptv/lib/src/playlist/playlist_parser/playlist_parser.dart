import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/m3u_parser/m3u_parser.dart';
import 'package:live_iptv/src/playlist/playlist_format/playlist_format.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';
import 'package:live_iptv/src/playlist/txt_parser/txt_parser.dart';

/// Parses [text] as a playlist of [format] (detected when null).
///
/// Both parsers are tolerant by design: a malformed line drops only
/// itself, never the whole playlist; URLs may carry `|`-suffixed headers
/// (`url|User-Agent=…&Referer=…`), which are split into the entry's
/// headers.
List<IptvEntry> parsePlaylist(String text, {IptvPlaylistFormat? format}) =>
    parsePlaylistResult(text, format: format).entries;

/// Parses a playlist and reports what it found wrong.
///
/// The result carries the entries *and* the problems, because the two
/// together are what an import has to decide on: a playlist whose last
/// `#EXTINF` never got its URL was cut off mid-download (truncated) and must
/// not replace a good saved one, while one with a handful of unparsable
/// lines imports fine and just says so.
PlaylistParseResult parsePlaylistResult(String text, {IptvPlaylistFormat? format}) {
  final actual = format ?? detectPlaylistFormat(text);
  return switch (actual) {
    IptvPlaylistFormat.m3u => parseM3uResult(text),
    IptvPlaylistFormat.txt => parseTxtResult(text),
    null => PlaylistParseResult(
      entries: const [],
      issues: const [PlaylistIssue(0, 'the text is neither an M3U nor a text playlist')],
    ),
  };
}
