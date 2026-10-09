// Module: lib/src/resolver.dart
// Purpose: The Resolver contract and the error a resolver throws when it cannot produce a ticket.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 12 and section 18: a resolver turns a ContentRef into
// tickets, never into a player (invariant 3), and its failure is expressed as a classified
// PlatformErrorInfo rather than a message a caller has to parse.

import 'package:pure_live_platform/pure_live_platform.dart';

/// One way of getting playable resources for content.
abstract interface class Resolver {
  ResolverDescriptor get descriptor;

  /// A cheap, offline answer: could this resolver serve [ref] at all? It must not perform a request, because
  /// a registry asks it about every candidate before choosing one.
  bool canResolve(ContentRef ref);

  Future<ResolveResult> resolve(ResolveRequest request);
}

/// A resolver's own refusal.
///
/// It carries a code from docs/contracts/platform-models.md section 14 (`resolver.unsupported`,
/// `resolver.failed`, `resolver.timeout`, `media.expired`) so the recovery ladder can branch on it: an
/// unsupported content kind is not retryable, a timeout is.
final class ResolverException implements Exception {
  const ResolverException(this.error);

  final PlatformErrorInfo error;

  String get code => error.code;

  factory ResolverException.unsupported(ContentRef ref, {String? reason}) => ResolverException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.resolverUnsupported,
      message: reason ?? 'no resolver serves ${ref.kind.name} ${ref.contentId}',
      category: PlatformErrorCategory.resolver,
    ),
  );

  factory ResolverException.failed(String subject, Object cause) => ResolverException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.resolverFailed,
      message: 'resolving $subject failed: $cause',
      category: PlatformErrorCategory.resolver,
      retryable: true,
      recoverable: true,
    ),
  );

  factory ResolverException.timedOut(ContentRef ref, Duration limit) => ResolverException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.resolverTimeout,
      message: 'resolving ${ref.contentId} exceeded ${limit.inSeconds}s',
      category: PlatformErrorCategory.timeout,
      retryable: true,
      recoverable: true,
    ),
  );

  factory ResolverException.expired(String ticketId) => ResolverException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.mediaExpired,
      message: 'ticket $ticketId was already expired when it was resolved',
      category: PlatformErrorCategory.media,
      retryable: true,
    ),
  );

  /// For a resolver that honours a caller's token: the caller asked, so this is an outcome, not a failure
  /// (platform-models.md section 20 invariant 9). [ResolverChain] rethrows it instead of trying the next
  /// candidate.
  factory ResolverException.cancelled(String contentId) => ResolverException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.taskCancelled,
      message: 'resolving $contentId was cancelled',
      category: PlatformErrorCategory.cancellation,
    ),
  );

  /// The contract's rule that a cancellation is not an error (platform-models.md section 20 invariant 9):
  /// callers that pass one rethrow the original signal instead of wrapping it.
  bool get isCancellation => code == PlatformErrorCodes.taskCancelled;

  @override
  String toString() => 'ResolverException(${error.code}: ${error.message})';
}
