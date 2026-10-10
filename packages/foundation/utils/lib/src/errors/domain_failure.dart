// Module: lib/src/errors/domain_failure.dart
// Purpose: The shared shape of a reported failure: a reason, an optional cause, and a stable toString.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: thirteen packages declare their own `class SomethingException implements Exception`
// with the same message field and the same toString, and each one forgets a slightly different part - some
// drop the cause, so a storage failure reaching diagnostics looks like a mystery. Domain types still own
// their names; this only gives them one way to carry what happened.
//
// A domain failure is not a Result. Result is for foreseeable outcomes a caller must branch on; this is for
// the genuinely exceptional ones that travel up to a handler or a log line.

/// A failure raised across a package boundary, carrying why and what it came from.
abstract class DomainFailure implements Exception {
  const DomainFailure(this.reason, {this.cause});

  /// A short human-readable explanation, in English, safe to log.
  ///
  /// It must not contain a token or a url credential: redaction is the caller's job on the way out, and a
  /// reason built from raw input inherits whatever was in it.
  final String reason;

  /// The error that made this one necessary, if any.
  ///
  /// Keeping it is what lets a handler tell "the store was corrupt" from "the store was corrupt because the
  /// file vanished mid-read" without a second exception type per combination.
  final Object? cause;

  @override
  String toString() {
    final source = cause;
    return source == null ? '$runtimeType: $reason' : '$runtimeType: $reason (cause: $source)';
  }
}

/// A failure that arrived without a domain type and is being reported as itself.
///
/// Wrapping beats inventing a per-call exception class, but it also beats letting a raw error escape: the
/// stack stays attached while the boundary still has one named type to match on.
final class UnexpectedFailure extends DomainFailure {
  const UnexpectedFailure(super.reason, {super.cause});

  /// Wraps [error] with the [context] of the operation that caught it.
  UnexpectedFailure.from(Object error, {required String context})
    : super('$context reported an untyped failure', cause: error);
}
