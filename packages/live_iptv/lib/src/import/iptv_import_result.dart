import 'package:live_iptv/src/playlist/playlist_parse_result.dart';

/// How an import or sync ended.
///
/// A status rather than an exception, because most of these are *answers*,
/// not failures: the user declining to replace a playlist is not an error,
/// and a source that turned out to hold no channels is a fact the screen
/// shows rather than a stack trace it logs.
enum IptvImportStatus {
  /// Imported and saved.
  imported,

  /// The user declined to replace what was already stored under that name.
  cancelled,

  /// The text is not a playlist this build reads, or holds no channels.
  unsupportedFormat,

  /// The file is broken — malformed, or cut off mid-download — so the
  /// stored data was kept.
  invalid,

  /// The download failed.
  networkFailed,

  /// What was being updated changed underneath (the playlist was deleted, or
  /// replaced by another import): nothing was written.
  stale,

  /// Anything else: a storage failure, an unexpected error.
  failed,
}

/// What an import or sync did.
class IptvImportResult {
  /// A result.
  new(this.status, {this.id, List<PlaylistIssue> issues = const [], this.error, this.channels = 0})
    : issues = List.unmodifiable(issues);

  /// How it ended.
  final IptvImportStatus status;

  /// The playlist record that was written, when one was.
  final String? id;

  /// How many channels the playlist carried, when it was read.
  final int channels;

  /// The lines that were skipped, for the screen and the log.
  final List<PlaylistIssue> issues;

  /// The error behind a failure, for logs — never for the user, whose
  /// message is the status.
  final Object? error;

  /// Whether anything was saved.
  bool get isImported => status == IptvImportStatus.imported;

  @override
  String toString() => 'IptvImportResult(${status.name}${error == null ? '' : ', $error'})';
}
