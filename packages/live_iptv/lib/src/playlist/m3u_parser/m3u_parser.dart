import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_format/playlist_format.dart';
import 'package:live_iptv/src/playlist/playlist_line/playlist_line.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';

/// Parses an extended M3U playlist.
///
/// Supports `#EXTINF` with `key="value"` attributes (`tvg-id`, `tvg-name`,
/// `tvg-logo`, `group-title`, `tvg-chno`, `catchup*`, and the request
/// attributes `http-user-agent`/`http-referrer`), `#EXTGRP` as the running
/// group, `#EXTVLCOPT`/`#KODIPROP` request options (`http-user-agent=`,
/// `http-referrer=`), the `url|headers` tail, and the `#EXTM3U` header's
/// guide addresses (`x-tvg-url`, `url-tvg`) and list-wide catchup template.
List<IptvEntry> parseM3u(String text) => parseM3uResult(text).entries;

/// Parses an extended M3U playlist and reports its problems.
///
/// A dangling `#EXTINF` at the end of the text (a stanza that never received
/// its URL) is reported as truncated rather than as a skipped line: it is the
/// signature of an interrupted download, and the caller decides what that
/// means for the data it already has.
///
/// Request options written before the first stanza belong to the whole list:
/// that is where a provider puts the user agent every one of its channels
/// needs, and reading them as the first channel's alone left the rest of the
/// list failing with the player's default agent.
PlaylistParseResult parseM3uResult(String text) {
  final entries = <IptvEntry>[];
  final issues = <PlaylistIssue>[];
  // The issue reports carry line numbers, so the walk counts lines rather
  // than only the lines it acts on.
  var lineNumber = 0;
  var dangling = false;
  var seenStanza = false;
  String? pendingName;
  var pendingAttributes = const <String, String>{};
  final headers = <String, String>{};
  final listHeaders = <String, String>{};
  String? currentGroup;
  final alternatives = <String>[];
  final guideUrls = <String>[];
  String? title;
  String? catchupMode;
  String? catchupSource;
  String? catchupDays;

  void flush(String urlLine) {
    final parsed = splitUrlHeaders(urlLine);
    final url = parsed.url;
    if (url.isEmpty) {
      return;
    }
    if (!looksLikePlaybackUrl(url)) {
      issues.add(PlaylistIssue(lineNumber, 'the address is not a URL: "$url"'));
      pendingName = null;
      pendingAttributes = const {};
      headers.clear();
      alternatives.clear();
      return;
    }
    // A channel that writes its own catchup keeps it whole; one that writes
    // none replays the way the header says the whole list does.
    final ownsCatchup =
        _nonEmpty(pendingAttributes['catchup']) != null || _nonEmpty(pendingAttributes['catchup-source']) != null;
    final allHeaders = {...listHeaders, ..._requestHeadersOf(pendingAttributes), ...headers, ...parsed.headers};
    final entry = IptvEntry.of(
      name: (pendingName ?? '').trim().isEmpty ? url : pendingName!.trim(),
      url: url,
      group: _nonEmpty(pendingAttributes['group-title']) ?? currentGroup,
      tvgId: _nonEmpty(pendingAttributes['tvg-id']),
      tvgName: _nonEmpty(pendingAttributes['tvg-name']),
      tvgLogo: _nonEmpty(pendingAttributes['tvg-logo']),
      channelNumber: channelNumberOf(pendingAttributes),
      headers: Map.unmodifiable(allHeaders),
      alternatives: List.unmodifiable(alternatives),
      catchupSource: ownsCatchup ? _nonEmpty(pendingAttributes['catchup-source']) : catchupSource,
      catchupMode: ownsCatchup ? _nonEmpty(pendingAttributes['catchup']) : catchupMode,
      catchupDays: _nonEmpty(pendingAttributes['catchup-days']) ?? catchupDays,
    );
    entries.add(entry);
    pendingName = null;
    pendingAttributes = const {};
    headers.clear();
    alternatives.clear();
  }

  for (final rawLine in text.split('\n')) {
    lineNumber++;
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#EXTM3U')) {
      // A list concatenated from several keeps every header it carried;
      // the first one speaks for the catchup, and every guide is kept.
      final attributes = _attributesOf(line);
      for (final key in const ['x-tvg-url', 'url-tvg', 'tvg-url']) {
        for (final address in (attributes[key] ?? '').split(',')) {
          final trimmed = address.trim();
          if (trimmed.isNotEmpty && !guideUrls.contains(trimmed)) {
            guideUrls.add(trimmed);
          }
        }
      }
      catchupMode ??= _nonEmpty(attributes['catchup']);
      catchupSource ??= _nonEmpty(attributes['catchup-source']);
      catchupDays ??= _nonEmpty(attributes['catchup-days']);
      for (final header in _requestHeadersOf(attributes).entries) {
        listHeaders.putIfAbsent(header.key, () => header.value);
      }
      continue;
    }
    if (line.startsWith('#PLAYLIST:')) {
      title ??= _nonEmpty(line.substring('#PLAYLIST:'.length));
      continue;
    }
    if (line.startsWith('#EXTINF:')) {
      if (dangling) {
        issues.add(PlaylistIssue(lineNumber - 1, 'an #EXTINF line was replaced before its URL arrived'));
      }
      dangling = true;
      seenStanza = true;
      pendingName = _nameOf(line);
      pendingAttributes = _attributesOf(line);
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      currentGroup = _nonEmpty(line.substring('#EXTGRP:'.length));
      continue;
    }
    if (line.startsWith('#EXTVLCOPT:') || line.startsWith('#KODIPROP:')) {
      final option = line.substring(line.indexOf(':') + 1).trim();
      final separator = option.indexOf('=');
      if (separator > 0) {
        final key = option.substring(0, separator).trim().toLowerCase();
        final value = option.substring(separator + 1).trim();
        final target = seenStanza ? headers : listHeaders;
        if (key == 'http-user-agent') {
          target['user-agent'] = value;
        } else if (key == 'http-referrer' || key == 'http-referer') {
          target['referer'] = value;
        }
      }
      continue;
    }
    if (line.startsWith('#')) {
      continue;
    }
    if (pendingName != null || pendingAttributes.isNotEmpty) {
      flush(line);
      dangling = false;
    } else if (alternatives.isEmpty && entries.isEmpty) {
      // A bare URL without EXTINF: still a channel.
      flush(line);
    } else if (pendingName == null && entries.isNotEmpty) {
      // A bare line right after a flushed entry is an alternative URL of
      // the current channel; tolerate it as its own channel instead — the
      // safer reading for malformed playlists.
      flush(line);
    } else {
      issues.add(PlaylistIssue(lineNumber, 'the line is neither a directive nor a URL'));
    }
  }
  if (dangling) {
    issues.add(PlaylistIssue(lineNumber, 'the playlist ends inside a stanza: the download was probably cut'));
  }
  return PlaylistParseResult(
    entries: entries,
    issues: issues,
    truncated: dangling,
    format: IptvPlaylistFormat.m3u,
    header: PlaylistHeader(
      guideUrls: List.unmodifiable(guideUrls),
      catchupMode: catchupMode,
      catchupSource: catchupSource,
      catchupDays: catchupDays,
      title: title,
      headers: Map.unmodifiable(listHeaders),
    ),
  );
}

/// The channel number a playlist declared for an entry, or null.
///
/// `tvg-chno` is the attribute the M3U spec carries it in, and providers
/// also write `tvg-number`; both are read, and a non-numeric or negative
/// value is no number at all — importing "01CCTV" as a channel number
/// would give the remote control something to type and the library nothing
/// to find. Leading zeros are the provider's formatting, not the user's:
/// `tvg-chno="001"` is channel 1.
int? channelNumberOf(Map<String, String> attributes) {
  for (final key in const ['tvg-chno', 'tvg-number']) {
    final raw = attributes[key]?.trim();
    if (raw == null || raw.isEmpty) {
      continue;
    }
    final number = int.tryParse(raw);
    if (number != null && number > 0) {
      return number;
    }
  }
  return null;
}

final RegExp _attribute = RegExp('([A-Za-z0-9_-]+)="([^"]*)"');

/// The display name of an `#EXTINF` line.
///
/// The name follows the first comma after the attributes — not the last
/// comma of the line, which cuts "News, Live" down to "Live" — and a line
/// that wrote no comma at all (`tvg-logo="…"CCTV1`, a shape whole provider
/// lists use) names its channel with whatever follows the last attribute.
/// Commas left in front of the name are a list's own typo (`",,CCTV1"`,
/// what a sed that added a comma where one already was leaves behind): no
/// channel's name starts with one.
String? _nameOf(String line) {
  final attributes = _attribute.allMatches(line).toList();
  final start = attributes.isEmpty ? '#EXTINF:'.length : attributes.last.end;
  final comma = line.indexOf(',', start);
  if (comma >= 0) {
    return line.substring(comma + 1).replaceFirst(RegExp(r'^[,\s]+'), '').trim();
  }
  if (attributes.isEmpty) {
    return null;
  }
  return _nonEmpty(line.substring(start));
}

/// The `key="value"` attributes of an `#EXTINF` or `#EXTM3U` line.
Map<String, String> _attributesOf(String line) {
  final attributes = <String, String>{};
  for (final match in _attribute.allMatches(line)) {
    attributes[match.group(1)!.toLowerCase()] = match.group(2)!;
  }
  return attributes;
}

/// The request headers a line's attributes carry.
Map<String, String> _requestHeadersOf(Map<String, String> attributes) {
  final headers = <String, String>{};
  final agent = _nonEmpty(attributes['http-user-agent'] ?? attributes['user-agent']);
  if (agent != null) {
    headers['user-agent'] = agent;
  }
  final referer = _nonEmpty(
    attributes['http-referrer'] ?? attributes['http-referer'] ?? attributes['referrer'] ?? attributes['referer'],
  );
  if (referer != null) {
    headers['referer'] = referer;
  }
  return headers;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
