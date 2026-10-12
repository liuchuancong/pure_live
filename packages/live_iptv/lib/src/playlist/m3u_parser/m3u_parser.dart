import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_line/playlist_line.dart';
import 'package:live_iptv/src/playlist/playlist_parse_result.dart';

/// Parses an extended M3U playlist.
///
/// Supports `#EXTINF` with `key="value"` attributes (`tvg-id`,
/// `tvg-logo`, `group-title`, `tvg-chno`, `catchup*`), `#EXTGRP` as the
/// running group, `#EXTVLCOPT`/`#KODIPROP` request options
/// (`http-user-agent=`, `http-referrer=`) and the `url|headers` tail.
List<IptvEntry> parseM3u(String text) => parseM3uResult(text).entries;

/// Parses an extended M3U playlist and reports its problems.
///
/// A dangling `#EXTINF` at the end of the text (a stanza that never received
/// its URL) is reported as truncated rather than as a skipped line: it is the
/// signature of an interrupted download, and the caller decides what that
/// means for the data it already has.
PlaylistParseResult parseM3uResult(String text) {
  final entries = <IptvEntry>[];
  final issues = <PlaylistIssue>[];
  // The issue reports carry line numbers, so the walk counts lines rather
  // than only the lines it acts on.
  var lineNumber = 0;
  var dangling = false;
  String? pendingName;
  var pendingAttributes = const <String, String>{};
  final headers = <String, String>{};
  String? currentGroup;
  final alternatives = <String>[];

  void flush(String urlLine) {
    final parsed = splitUrlHeaders(urlLine);
    final url = parsed.url;
    if (url.isEmpty) {
      return;
    }
    if (!_looksLikeUrl(url)) {
      issues.add(PlaylistIssue(lineNumber, 'the address is not a URL: "$url"'));
      pendingName = null;
      pendingAttributes = const {};
      headers.clear();
      alternatives.clear();
      return;
    }
    final allHeaders = {...headers, ...parsed.headers};
    final entry = IptvEntry(
      name: (pendingName ?? '').trim().isEmpty ? url : pendingName!.trim(),
      url: url,
      group: pendingAttributes['group-title'] ?? currentGroup,
      tvgId: pendingAttributes['tvg-id'],
      tvgLogo: pendingAttributes['tvg-logo'],
      channelNumber: channelNumberOf(pendingAttributes),
      headers: Map.unmodifiable(allHeaders),
      alternatives: List.unmodifiable(alternatives),
      catchupSource: pendingAttributes['catchup-source'],
      catchupMode: pendingAttributes['catchup'],
      catchupDays: pendingAttributes['catchup-days'],
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
    if (line.startsWith('#EXTINF:')) {
      if (dangling) {
        issues.add(PlaylistIssue(lineNumber - 1, 'an #EXTINF line was replaced before its URL arrived'));
      }
      dangling = true;
      pendingName = _nameOf(line);
      pendingAttributes = _attributesOf(line);
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      currentGroup = line.substring('#EXTGRP:'.length).trim();
      continue;
    }
    if (line.startsWith('#EXTVLCOPT:') || line.startsWith('#KODIPROP:')) {
      final option = line.substring(line.indexOf(':') + 1).trim();
      final separator = option.indexOf('=');
      if (separator > 0) {
        final key = option.substring(0, separator).trim().toLowerCase();
        final value = option.substring(separator + 1).trim();
        if (key == 'http-user-agent') {
          headers['user-agent'] = value;
        } else if (key == 'http-referrer' || key == 'http-referer') {
          headers['referer'] = value;
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
  return PlaylistParseResult(entries: entries, issues: issues, truncated: dangling);
}

/// Whether [value] looks like a playback address.
///
/// A scheme is required (http, https, rtmp, rtsp, udp, file all carry
/// `://`), and a protocol-relative address is accepted because some
/// playlists write them. Everything else — a note, a name, a comment that
/// lost its `#` — is not something any player can open, and importing it as
/// a channel hides the fact that the line was broken.
bool _looksLikeUrl(String value) {
  final text = value.trim();
  if (text.startsWith('//')) {
    return true;
  }
  final scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').firstMatch(text);
  return scheme != null;
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

/// The display name of an `#EXTINF` line (after the last comma).
String? _nameOf(String line) {
  final comma = line.lastIndexOf(',');
  if (comma < 0) {
    return null;
  }
  return line.substring(comma + 1).trim();
}

/// The `key="value"` attributes of an `#EXTINF` line.
Map<String, String> _attributesOf(String line) {
  final attributes = <String, String>{};
  for (final match in RegExp('([A-Za-z0-9_-]+)="([^"]*)"').allMatches(line)) {
    attributes[match.group(1)!.toLowerCase()] = match.group(2)!;
  }
  return attributes;
}
