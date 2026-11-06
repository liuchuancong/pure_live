/// The classes of failure the cache distinguishes.
enum CacheFailureKind {
  /// No usable copy exists and the policy forbids a network request.
  notFound,

  /// The transport exceeded a connect, send or receive timeout.
  timeout,

  /// The server answered with a non-success status.
  http,

  /// The body is not an image format the cache accepts.
  unsupportedFormat,

  /// A cached file could not be decoded and was discarded.
  corrupted,

  /// The body or a cached file exceeds the per-image size limit.
  tooLarge,

  /// The disk refused a write because it is full.
  diskFull,

  /// The process may not create or write the cache folder.
  permission,

  /// The server answered successfully with an empty body.
  empty,

  /// The connection could not be established.
  offline,

  /// Anything that does not fit the classes above.
  unknown,
}

/// A cache failure with its class, an optional human-readable detail and the
/// HTTP status when the server supplied one.
///
/// The cache reports failures to the image pipeline instead of throwing
/// across a page: a broken image keeps the caller's placeholder, never the
/// page.
final class CacheFailure implements Exception {
  /// Creates a failure of [kind].
  const new(this.kind, {this.message, this.statusCode, this.cause});

  /// What went wrong.
  final CacheFailureKind kind;

  /// A detail safe to log or show; never a URL with credentials.
  final String? message;

  /// The HTTP status behind an [CacheFailureKind.http] failure.
  final int? statusCode;

  /// The underlying error when one exists.
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final detail = message == null ? '' : ': $message';
    return 'CacheFailure(${kind.name}$status)$detail';
  }
}
