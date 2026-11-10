import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_format/playlist_format.dart';
import 'package:live_iptv/src/playlist/playlist_line/playlist_line.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';

/// Parses the plain text list format.
///
/// `name,url` lines belong to the running `group,#genre#` header; `#`
/// separates alternative URLs of one channel.
List<IptvEntry> parseTxt(String text) => parseTxtResult(text).entries;

/// Parses the plain text list format and reports its problems.
///
/// Lists typed on a phone use the full-width comma, and TVBox-style lists
/// name each line with a `$label` suffix; both are read. A line whose
/// address is not one a player can open is reported, not imported: a text
/// list has no syntax to tell a channel from a sentence with a comma in it,
/// so the address is the only proof that a line is a channel.
PlaylistParseResult parseTxtResult(String text) {
  final entries = <IptvEntry>[];
  final issues = <PlaylistIssue>[];
  var group = '';
  var lineNumber = 0;
  for (final rawLine in text.split('\n')) {
    lineNumber++;
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    var separator = line.indexOf(',');
    final wide = line.indexOf('，');
    if (separator < 0 || (wide >= 0 && wide < separator)) {
      separator = wide;
    }
    if (separator < 0) {
      // A bare address is still a channel; anything else is a line the
      // list did not mean as one.
      final address = _addressOf(line);
      if (looksLikePlaybackUrl(address.url)) {
        entries.add(IptvEntry.of(name: address.url, url: address.url, headers: Map.unmodifiable(address.headers)));
      } else {
        issues.add(PlaylistIssue(lineNumber, 'the line is neither a channel nor a group'));
      }
      continue;
    }
    if (separator == 0) {
      issues.add(PlaylistIssue(lineNumber, 'the line has no channel name'));
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
      issues.add(PlaylistIssue(lineNumber, 'the channel "$name" has no address'));
      continue;
    }
    final primary = _addressOf(urls.first);
    if (!looksLikePlaybackUrl(primary.url)) {
      issues.add(PlaylistIssue(lineNumber, 'the address is not a URL: "${primary.url}"'));
      continue;
    }
    final fallbacks = <String>[
      for (final url in urls.skip(1))
        if (_addressOf(url).url case final address when looksLikePlaybackUrl(address) && address != primary.url)
          address,
    ];
    entries.add(
      IptvEntry.of(
        name: name,
        url: primary.url,
        group: group.isEmpty ? null : group,
        headers: Map.unmodifiable(primary.headers),
        alternatives: List.unmodifiable(fallbacks),
      ),
    );
  }
  return PlaylistParseResult(entries: entries, issues: issues, format: IptvPlaylistFormat.txt);
}

/// One address of a text line: the `|headers` tail split off and the
/// TVBox `$label` suffix dropped.
({String url, Map<String, String> headers}) _addressOf(String raw) {
  final parsed = splitUrlHeaders(raw);
  final dollar = parsed.url.indexOf(r'$');
  final url = dollar > 0 ? parsed.url.substring(0, dollar).trim() : parsed.url;
  return (url: url, headers: parsed.headers);
}

/// Whether [text] is the TXT format's group marker (`#genre#`, `#genre`).
bool _isGenreHeader(String text) {
  final stripped = text.replaceAll('#', '').trim().toLowerCase();
  return stripped == 'genre' || stripped.isEmpty;
}
