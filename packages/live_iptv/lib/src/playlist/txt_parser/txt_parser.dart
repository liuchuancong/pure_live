import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_line/playlist_line.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';

/// Parses the plain text list format.
///
/// `name,url` lines belong to the running `group,#genre#` header; `#`
/// separates alternative URLs of one channel.
List<IptvEntry> parseTxt(String text) => parseTxtResult(text).entries;

/// Parses the plain text list format and reports its problems.
PlaylistParseResult parseTxtResult(String text) {
  final entries = <IptvEntry>[];
  final issues = <PlaylistIssue>[];
  var group = '';
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf(',');
    if (separator <= 0) {
      continue;
    }
    final name = line.substring(0, separator).trim();
    final rest = line.substring(separator + 1).trim();
    if (_isGenreHeader(rest)) {
      // `name,#genre#` heads a group; providers also write `#genre` without
      // the closing hash, and a header read as a channel would put a bogus
      // "央视" channel with the URL "#genre#" in the library.
      group = name;
      continue;
    }
    final urls = [
      for (final url in rest.split('#'))
        if (url.trim().isNotEmpty) url.trim(),
    ];
    if (urls.isEmpty) {
      continue;
    }
    final parsed = splitUrlHeaders(urls.first);
    entries.add(
      IptvEntry(
        name: name.isEmpty ? parsed.url : name,
        url: parsed.url,
        group: group.isEmpty ? null : group,
        headers: Map.unmodifiable(parsed.headers),
        alternatives: urls.length > 1 ? List.unmodifiable(urls.sublist(1)) : const [],
      ),
    );
  }
  return PlaylistParseResult(entries: entries, issues: issues);
}

/// Whether [text] is the TXT format's group marker (`#genre#`, `#genre`).
bool _isGenreHeader(String text) {
  final stripped = text.replaceAll('#', '').trim().toLowerCase();
  return stripped == 'genre' || stripped.isEmpty;
}
