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

/// Why an import that saved nothing failed, finer than its status: the
/// difference between "the server said 404" and "the server never answered"
/// is the difference between fixing the address and trying again later, and
/// a screen that only had the status could say neither.
enum IptvImportFailure {
  /// The server answered with an error status ([IptvImportResult.statusCode]).
  httpStatus,

  /// The server took longer than the download may.
  timeout,

  /// The server could not be reached at all: the name did not resolve, the
  /// connection was refused or dropped.
  unreachable,

  /// The secure connection could not be established.
  tls,

  /// A web page came back instead of a list: a dead link's error page, a
  /// login wall, a repository page copied instead of its raw file.
  webPage,

  /// A programme guide came back where a playlist was expected.
  guideFile,

  /// The text read as nothing: no line of it is a channel.
  noChannels,

  /// The text ends inside a stanza: the download was cut off.
  truncated,

  /// The bytes are not text this build can read (compression that does not
  /// inflate, a file too large to be a list).
  unreadable,

  /// The name belongs to another source.
  nameTaken,

  /// Saving failed.
  storage,
}

/// What an import or sync did.
class IptvImportResult {
  /// A result.
  new(
    this.status, {
    this.id,
    List<PlaylistIssue> issues = const [],
    this.error,
    this.channels = 0,
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.failure,
    this.statusCode,
  }) : issues = List.unmodifiable(issues);

  /// How it ended.
  final IptvImportStatus status;

  /// The playlist record that was written, when one was.
  final String? id;

  /// How many channels the playlist carried, when it was read.
  final int channels;

  /// How many of them were new to the library.
  final int added;

  /// How many of them the library already held, and refreshed.
  final int updated;

  /// How many channels left the library because the source stopped listing
  /// them.
  final int removed;

  /// The lines that were skipped, for the screen and the log.
  final List<PlaylistIssue> issues;

  /// Why nothing was saved, when that is known more precisely than [status].
  final IptvImportFailure? failure;

  /// The HTTP status the server answered with, for [IptvImportFailure.httpStatus].
  final int? statusCode;

  /// The error behind a failure, for logs and the "copy details" a screen
  /// offers — never the sentence the user reads, which is the status and
  /// [failure] worded.
  final Object? error;

  /// Whether anything was saved.
  bool get isImported => status == IptvImportStatus.imported;

  @override
  String toString() =>
      'IptvImportResult(${status.name}${failure == null ? '' : '/${failure!.name}'}'
      '${statusCode == null ? '' : ' $statusCode'}${error == null ? '' : ', $error'})';
}
