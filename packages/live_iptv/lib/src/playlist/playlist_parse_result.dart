import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_format/playlist_format.dart';

/// One problem in a playlist, as a parser found it.
///
/// Reported rather than thrown: a playlist with three broken lines out of
/// two thousand is a playlist worth importing, and the user deserves to know
/// which three. The message is for logs and diagnostics, not for the screen —
/// the screen shows the count.
class PlaylistIssue {
  /// An issue at `line`, or at the whole file when [line] is 0.
  const new(this.line, this.message);

  /// The 1-based line number, or 0 for a problem with the file itself.
  final int line;

  /// What is wrong.
  final String message;

  @override
  String toString() => line == 0 ? message : 'Line $line: $message';
}

/// What a playlist said about itself rather than about one channel: the
/// `#EXTM3U` header's attributes, its `#PLAYLIST:` title, and the request
/// options written ahead of the first stanza.
///
/// A provider that ships a guide names it here (`x-tvg-url`), and one whose
/// whole list replays the same way writes the catchup template once here
/// instead of on every channel — so an importer that read only the stanzas
/// would lose both the guide and the replay of every channel in the list.
class PlaylistHeader {
  /// A header.
  const new({
    this.guideUrls = const [],
    this.catchupMode,
    this.catchupSource,
    this.catchupDays,
    this.title,
    this.headers = const {},
  });

  /// The guide addresses the header declared (`x-tvg-url`, `url-tvg`), in
  /// the order it wrote them: the first is the provider's choice, the rest
  /// its mirrors.
  final List<String> guideUrls;

  /// The list-wide catchup mode (`catchup`), applied to channels that do not
  /// declare their own.
  final String? catchupMode;

  /// The list-wide catchup template (`catchup-source`).
  final String? catchupSource;

  /// The list-wide replay window (`catchup-days`).
  final String? catchupDays;

  /// The playlist's own name (`#PLAYLIST:`), when it wrote one.
  final String? title;

  /// The request headers every channel inherits.
  final Map<String, String> headers;

  /// Whether the header names a guide.
  bool get declaresGuide => guideUrls.isNotEmpty;

  /// Whether the header gives the whole list a replay template.
  bool get declaresCatchup => (catchupMode ?? '').isNotEmpty || (catchupSource ?? '').isNotEmpty;
}

/// What a playlist parser read.
class PlaylistParseResult {
  /// A parse result.
  new({
    required List<IptvEntry> entries,
    List<PlaylistIssue> issues = const [],
    this.truncated = false,
    this.header = const PlaylistHeader(),
    this.format,
    this.markup,
    this.mergedLines = 0,
  }) : entries = List.unmodifiable(entries),
       issues = List.unmodifiable(issues);

  /// The entries, in file order.
  final List<IptvEntry> entries;

  /// The skipped lines and other problems.
  final List<PlaylistIssue> issues;

  /// Whether the text ends inside a stanza — an `#EXTINF` whose URL never
  /// arrived, which usually means the download was cut off.
  ///
  /// Worth its own flag rather than an issue: a truncated playlist imports
  /// fine and looks complete, and it must not replace a saved one. Only the
  /// caller can decide that, so the parser reports the fact instead of
  /// guessing.
  final bool truncated;

  /// What the playlist said about itself.
  final PlaylistHeader header;

  /// The format the text was read as; null when it was not read at all.
  final IptvPlaylistFormat? format;

  /// The markup the text turned out to be instead of a playlist — the web
  /// page a host answers a dead link with, or a guide imported in the
  /// playlist's place — or null when it is not markup.
  final PlaylistMarkup? markup;

  /// How many stanzas [mergeDuplicates] folded into another channel's lines.
  final int mergedLines;

  /// Whether anything was wrong.
  bool get hasIssues => issues.isNotEmpty;

  /// Whether there is anything usable.
  bool get isEmpty => entries.isEmpty;

  /// How many entries each group holds, in the order the groups first
  /// appear; entries that name no group count under the empty string.
  Map<String, int> get groupCounts {
    final counts = <String, int>{};
    for (final entry in entries) {
      final group = entry.group ?? '';
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  /// How many entries carry more than one address.
  int get multiLineCount => entries.where((entry) => entry.alternatives.isNotEmpty).length;

  /// This result keeping only the entries [keep] accepts.
  PlaylistParseResult where(bool Function(IptvEntry entry) keep) {
    final kept = entries.where(keep).toList();
    if (kept.length == entries.length) {
      return this;
    }
    return PlaylistParseResult(
      entries: kept,
      issues: issues,
      truncated: truncated,
      header: header,
      format: format,
      markup: markup,
      mergedLines: mergedLines,
    );
  }

  /// This result with the stanzas that repeat a channel folded into one
  /// entry, the repeats' addresses becoming its fallback lines.
  ///
  /// Providers list a channel once per line ("CCTV1" five times, one per
  /// CDN), and a library that kept them apart would show five channels the
  /// viewer cannot tell apart while the player's line switching had nothing
  /// to switch between. A repeat is the same name in the same group; a name
  /// shared across groups stays two channels, because the group is part of
  /// what the provider meant by it. A repeat that needs other request
  /// headers stays its own channel too: the player sends one set of headers
  /// per channel, and the fallback would fail with the wrong ones.
  PlaylistParseResult mergeDuplicates() {
    final merged = <IptvEntry>[];
    final firstOf = <String, int>{};
    var folded = 0;
    for (final entry in entries) {
      final key = _duplicateKey(entry);
      final at = firstOf[key];
      if (at == null) {
        firstOf[key] = merged.length;
        merged.add(entry);
        continue;
      }
      final first = merged[at];
      if (!_sameHeaders(first, entry)) {
        merged.add(entry);
        continue;
      }
      final known = <String>{first.url, ...first.alternatives};
      final extra = [
        for (final url in [entry.url, ...entry.alternatives])
          if (known.add(url)) url,
      ];
      merged[at] = first.rebuild(
        (b) => b
          ..alternatives.addAll(extra)
          ..tvgId ??= entry.tvgId
          ..tvgName ??= entry.tvgName
          ..tvgLogo ??= entry.tvgLogo
          ..channelNumber ??= entry.channelNumber
          ..catchupSource ??= entry.catchupSource
          ..catchupMode ??= entry.catchupMode
          ..catchupDays ??= entry.catchupDays,
      );
      folded++;
    }
    if (folded == 0) {
      return this;
    }
    return PlaylistParseResult(
      entries: merged,
      issues: issues,
      truncated: truncated,
      header: header,
      format: format,
      markup: markup,
      mergedLines: mergedLines + folded,
    );
  }

  static String _duplicateKey(IptvEntry entry) {
    final group = (entry.group ?? '').trim().toLowerCase();
    final name = entry.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '$group\u0000$name';
  }

  static bool _sameHeaders(IptvEntry a, IptvEntry b) {
    if (a.headers.length != b.headers.length) {
      return false;
    }
    for (final entry in a.headers.entries) {
      if (b.headers[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
