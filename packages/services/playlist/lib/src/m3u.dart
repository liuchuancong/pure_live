// Module: lib/src/m3u.dart
// Purpose: Import and export a playlist as M3U, the one format every external list already arrives in.
// Author: liuchuancong
// Created: 2026-10-11
//
// playlist.md puts "导入导出" in the service's job list, and an imported list is not a JSON array of our own
// shape - it is an M3U someone else wrote, with an unknown directive per station, a duration of -1 because the
// author did not know, a title with a comma in it, and either a bare path or an absolute URL. Refusing the
// format's messiness would refuse the files, so the parser reports what it did not understand and keeps going,
// and the exporter writes only what the format can hold.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'playlist.dart';

/// One entry as an M3U file describes it.
final class M3uEntry {
  const M3uEntry({
    required this.title,
    required this.location,
    this.duration = const Duration(seconds: -1),
    this.group,
    this.options = const <String>[],
    this.line,
  });

  final String title;

  /// The path or URL line under the `#EXTINF`. Absolute ones are kept as they are; a relative one is resolved
  /// against the import's base, because "the ts file sitting next to this playlist" is how these lists are built.
  final String location;

  /// `#EXTINF`'s seconds. Negative means the file did not say, which is the common case, and is kept negative
  /// rather than defaulted to zero: zero is a claim, unknown is not.
  final Duration duration;

  /// `#EXTGRP`, when present. It is how a list groups by channel, and this app has the same notion.
  final String? group;

  /// Directives this parser recognised but does not model (`#EXTVLCOPT`, `#EXTBYT`, ...). Kept so an export can
  /// say the round trip is not loss-free.
  final List<String> options;

  /// The 1-based line the entry started on, for a report that points at the file rather than at an index.
  final int? line;

  @override
  String toString() => 'M3uEntry($title -> $location${group == null ? '' : ' [$group]'})';
}

/// What an import did, including everything it did not understand.
final class M3uImport {
  const M3uImport({
    required this.entries,
    required this.ignoredDirectives,
    required this.droppedLines,
    required this.hasHeader,
    required this.duplicateLocations,
    this.truncated = false,
  });

  final List<M3uEntry> entries;

  /// Directive names seen but not modelled, counted once each.
  final Map<String, int> ignoredDirectives;

  /// Lines that were neither a directive nor a usable location, plus any past the bound.
  final int droppedLines;

  /// False for a file without `#EXTM3U`. It still parses - a plain list of paths is common - but the caller
  /// should know the header was missing before it treats the result as a standard playlist.
  final bool hasHeader;

  /// Locations appearing more than once. Not an error: an M3U legitimately lists the same stream twice, and
  /// `Playlist` allows a repeated ref by design.
  final int duplicateLocations;

  /// True when the file had more entries than [parseM3u]'s bound allows. Reported, never silent: "the file has
  /// more" is a thing the import screen has to say.
  final bool truncated;

  bool get isClean => droppedLines == 0 && ignoredDirectives.isEmpty && !truncated;

  @override
  String toString() =>
      'M3uImport(${entries.length} entries${hasHeader ? '' : ', no header'}, '
      '$droppedLines dropped, ${ignoredDirectives.length} unknown directives${truncated ? ', truncated' : ''})';
}

/// Parses M3U / M3U8 text.
///
/// [maxEntries] bounds the parse: an imported file is untrusted input, and a list of a million rows is both a
/// memory problem and a playlist no user will scroll.
M3uImport parseM3u(String text, {Uri? baseUri, int maxEntries = 5000}) {
  if (maxEntries < 1) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'must allow at least one entry');
  }
  final entries = <M3uEntry>[];
  final ignored = <String, int>{};
  final seen = <String>{};
  var dropped = 0;
  var duplicates = 0;
  var truncated = false;
  var hasHeader = false;
  String? pendingTitle;
  Duration pendingDuration = const Duration(seconds: -1);
  String? pendingGroup;
  final pendingOptions = <String>[];
  var pendingLine = 0;
  var lineNumber = 0;

  void countDirective(String name) {
    ignored[name] = (ignored[name] ?? 0) + 1;
  }

  for (final raw in const M3uLines().split(text)) {
    lineNumber++;
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#')) {
      final name = _directiveName(line);
      switch (name) {
        case 'EXTM3U':
          hasHeader = true;
        case 'EXTINF':
          if (pendingTitle != null) {
            // Two EXTINF lines with no location between them: the first is counted as dropped rather than
            // inherited, because inheriting would invent an entry nobody wrote.
            dropped++;
          }
          final parsed = _parseExtInf(line);
          pendingTitle = parsed.title;
          pendingDuration = parsed.duration;
          pendingLine = lineNumber;
        case 'EXTGRP':
          pendingGroup = _directiveValue(line);
        case 'EXTVLCOPT':
        case 'EXTBYT':
        case 'EXTMBR':
        case 'EXT-X-KEY':
        case 'EXT-X-STREAM-INF':
        case 'EXT-X-TARGETDURATION':
          pendingOptions.add(line);
          countDirective(name);
        default:
          countDirective(name.isEmpty ? '#' : name);
      }
      continue;
    }
    if (pendingTitle == null && pendingOptions.isEmpty && pendingGroup == null) {
      // A bare list of paths (no #EXTM3U at all) is valid input: the title is then the last path segment.
      pendingTitle = _fallbackTitle(line);
      pendingLine = lineNumber;
    }
    final location = _resolveLocation(line, baseUri);
    if (location == null) {
      dropped++;
      continue;
    }
    if (entries.length >= maxEntries) {
      truncated = true;
      continue;
    }
    if (!seen.add(location)) {
      duplicates++;
    }
    entries.add(
      M3uEntry(
        title: pendingTitle == null || pendingTitle.isEmpty ? _fallbackTitle(location) : pendingTitle,
        location: location,
        duration: pendingDuration,
        group: pendingGroup,
        options: List<String>.unmodifiable(pendingOptions),
        line: pendingLine,
      ),
    );
    pendingTitle = null;
    pendingDuration = const Duration(seconds: -1);
    pendingGroup = null;
    pendingOptions.clear();
  }

  return M3uImport(
    entries: List<M3uEntry>.unmodifiable(entries),
    ignoredDirectives: Map<String, int>.unmodifiable(ignored),
    droppedLines: dropped,
    hasHeader: hasHeader,
    duplicateLocations: duplicates,
    truncated: truncated,
  );
}

/// The rows of [entries] as playlist items, keyed by [refFor].
///
/// The caller supplies the mapping because only it knows what a location means here: an IPTV line becomes a
/// channel ref, a music URL becomes a track ref, and neither belongs in a format parser. A row whose ref cannot
/// be resolved is skipped by the caller's own rule, so this function reports nothing - the count that matters is
/// `entries.length - items.length` at the call site.
List<PlaylistItem> itemsFromM3u(Iterable<M3uEntry> entries, {required ContentRef? Function(M3uEntry entry) refFor}) {
  final items = <PlaylistItem>[];
  for (final entry in entries) {
    final ref = refFor(entry);
    if (ref == null) {
      continue;
    }
    items.add(
      PlaylistItem(
        ref: ref,
        snapshot: ContentSummary(
          ref: ref,
          title: entry.title.isEmpty ? '${ref.sourceId}/${ref.contentId}' : entry.title,
          description: entry.group,
        ),
      ),
    );
  }
  return items;
}

/// Writes an M3U document. [urlFor] is required for the same reason [itemsFromM3u] takes `refFor`: this layer
/// does not know how to turn a content reference into an address.
String writeM3u(Iterable<PlaylistItem> items, {required String Function(PlaylistItem item) urlFor, String? group}) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (final item in items) {
    final title = item.snapshot.title.replaceAll(RegExp(r'[\r\n]'), ' ');
    buffer.write('#EXTINF:-1,$title\n');
    if (group != null && group.isNotEmpty) {
      buffer.write('#EXTGRP:$group\n');
    }
    buffer.write('${urlFor(item)}\n');
  }
  return buffer.toString();
}

/// Splits on any of the three line endings an M3U can carry.
///
/// A file exported by an old Windows tool with bare `\r` is not rare, and reading it as one line turns the whole
/// import into a single dropped line.
final class M3uLines {
  const M3uLines();

  List<String> split(String text) => text.split(RegExp(r'\r\n|\r|\n'));
}

String _directiveName(String line) {
  final withoutHash = line.substring(1);
  final end = withoutHash.indexOf(RegExp(r'[:\s]'));
  return end < 0 ? withoutHash : withoutHash.substring(0, end);
}

String _directiveValue(String line) {
  final colon = line.indexOf(':');
  return colon < 0 ? '' : line.substring(colon + 1).trim();
}

({String title, Duration duration}) _parseExtInf(String line) {
  final value = _directiveValue(line);
  // Duration and title split on the FIRST comma only: titles carry commas ("Amor, Amor"), and splitting on the
  // last one is how those files lose half their names.
  final comma = value.indexOf(',');
  final seconds = comma < 0 ? value : value.substring(0, comma);
  final title = comma < 0 ? '' : value.substring(comma + 1).trim();
  final parsed = double.tryParse(seconds.trim());
  return (title: title, duration: parsed == null ? const Duration(seconds: -1) : Duration(seconds: parsed.round()));
}

String? _resolveLocation(String line, Uri? baseUri) {
  final text = line.trim();
  if (text.isEmpty || text.startsWith('#')) {
    return null;
  }
  if (baseUri == null || text.contains('://') || text.startsWith('/') || text.startsWith(r'\')) {
    return text;
  }
  return baseUri.resolve(text).toString();
}

String _fallbackTitle(String location) {
  final trimmed = location.trim();
  final slash = trimmed.lastIndexOf(RegExp(r'[/\\]'));
  final name = slash < 0 ? trimmed : trimmed.substring(slash + 1);
  if (name.isEmpty) {
    return trimmed;
  }
  final withoutQuery = name.split(RegExp(r'[?#]')).first;
  return withoutQuery.isEmpty ? name : withoutQuery;
}
