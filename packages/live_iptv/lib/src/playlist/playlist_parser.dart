import 'package:live_iptv/src/model/iptv_models.dart';

/// The playlist format the parser recognised.
enum IptvPlaylistFormat {
  /// Extended M3U (`#EXTM3U` first line).
  m3u,

  /// The plain `name,url` / `group,#genre#` text lists.
  txt,
}

/// Detects [text]'s format, or null when it is neither.
IptvPlaylistFormat? detectPlaylistFormat(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('#EXTM3U')) {
    return IptvPlaylistFormat.m3u;
  }
  if (trimmed.isEmpty) {
    return null;
  }
  return IptvPlaylistFormat.txt;
}

/// Parses [text] as a playlist of [format] (detected when null).
///
/// Both parsers are tolerant by design: a malformed line drops only
/// itself, never the whole playlist; URLs may carry `|`-suffixed headers
/// (`url|User-Agent=…&Referer=…`), which are split into the entry's
/// headers.
List<IptvEntry> parsePlaylist(String text, {IptvPlaylistFormat? format}) {
  final actual = format ?? detectPlaylistFormat(text);
  return switch (actual) {
    IptvPlaylistFormat.m3u => parseM3u(text),
    IptvPlaylistFormat.txt => parseTxt(text),
    null => const [],
  };
}

/// Parses an extended M3U playlist.
///
/// Supports `#EXTINF` with `key="value"` attributes (`tvg-id`,
/// `tvg-logo`, `group-title`, `catchup*`), `#EXTGRP` as the running
/// group, `#EXTVLCOPT`/`#KODIPROP` request options
/// (`http-user-agent=`, `http-referrer=`) and the `url|headers` tail.
List<IptvEntry> parseM3u(String text) {
  final entries = <IptvEntry>[];
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
    final allHeaders = {...headers, ...parsed.headers};
    final entry = IptvEntry(
      name: (pendingName ?? '').trim().isEmpty ? url : pendingName!.trim(),
      url: url,
      group: pendingAttributes['group-title'] ?? currentGroup,
      tvgId: pendingAttributes['tvg-id'],
      tvgLogo: pendingAttributes['tvg-logo'],
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
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#EXTINF:')) {
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
    } else if (alternatives.isEmpty && entries.isEmpty) {
      // A bare URL without EXTINF: still a channel.
      flush(line);
    } else if (pendingName == null && entries.isNotEmpty) {
      // A bare line right after a flushed entry is an alternative URL of
      // the current channel; tolerate it as its own channel instead — the
      // safer reading for malformed playlists.
      flush(line);
    }
  }
  return entries;
}

/// Parses the plain text list format.
///
/// `name,url` lines belong to the running `group,#genre#` header; `#`
/// separates alternative URLs of one channel.
List<IptvEntry> parseTxt(String text) {
  final entries = <IptvEntry>[];
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
    if (rest.replaceAll('#', '').trim().isEmpty) {
      // `name,#genre#` heads a group.
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
  return entries;
}

/// Splits `url` from a `url|Key=Value&Key2=Value2` tail.
({String url, Map<String, String> headers}) splitUrlHeaders(String line) {
  final separator = line.indexOf('|');
  if (separator < 0) {
    return (url: line.trim(), headers: const {});
  }
  final url = line.substring(0, separator).trim();
  final tail = line.substring(separator + 1);
  final headers = <String, String>{};
  for (final pair in tail.split('&')) {
    final equals = pair.indexOf('=');
    if (equals <= 0) {
      continue;
    }
    final key = pair.substring(0, equals).trim().toLowerCase();
    final value = pair.substring(equals + 1).trim();
    if (key == 'user-agent') {
      headers['user-agent'] = value;
    } else if (key == 'referer' || key == 'referrer') {
      headers['referer'] = value;
    }
  }
  return (url: url, headers: headers);
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
