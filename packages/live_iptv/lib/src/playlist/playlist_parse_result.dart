import 'package:live_iptv/src/model/iptv_models.dart';

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

/// What a playlist parser read.
class PlaylistParseResult {
  /// A parse result.
  new({required List<IptvEntry> entries, List<PlaylistIssue> issues = const [], this.truncated = false})
    : entries = List.unmodifiable(entries),
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

  /// Whether anything was wrong.
  bool get hasIssues => issues.isNotEmpty;

  /// Whether there is anything usable.
  bool get isEmpty => entries.isEmpty;
}
