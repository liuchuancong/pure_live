// Module: lib/src/capability_resolver.dart
// Purpose: Turn a source's ResolveCapability into a Resolver the registry can select.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 10 ("Provider 是实现侧,Capability 是平台侧") and
// section 12 (and docs/adr/0021-resolver-capability-edge.md): a Resolver is what the platform consumes, so
// anything that only implements a capability has to
// be lifted into one. This adapter is that lift, and it is the only place a capability's ticket becomes a
// ResolveResult.

import 'dart:async';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'resolver.dart';

/// A Resolver over one source's ResolveCapability.
final class CapabilityResolver implements Resolver {
  CapabilityResolver({
    required this.descriptor,
    required this.capability,
    this.allowedKinds,
    this.clock,
    this.timeout = kDefaultResolveTimeout,
  });

  /// How long a source may take to answer before the platform moves on.
  ///
  /// A resolve is one round trip plus a redirect, so a budget here is not a tuning knob for slow networks:
  /// without it, one hung provider stalls playback start indefinitely while the ladder that exists to
  /// recover from a dead source never gets to run. `ResolverException.timedOut` was defined from the start
  /// and nothing threw it - the timeout was a documented behaviour with no code enforcing it.
  static const Duration kDefaultResolveTimeout = Duration(seconds: 12);

  /// The budget applied to [ResolveCapability.resolve] and to a refresh. Zero disables the limit.
  final Duration timeout;

  @override
  final ResolverDescriptor descriptor;

  final ResolveCapability capability;

  /// Narrows the kinds beyond what [ResolverDescriptor.serves] allows, for a source that resolves one
  /// content family only.
  final Set<ContentKind>? allowedKinds;

  final DateTime Function()? clock;

  @override
  bool canResolve(ContentRef ref) {
    if (!descriptor.serves(ref.kind)) {
      return false;
    }
    final allowed = allowedKinds;
    return allowed == null || allowed.contains(ref.kind);
  }

  @override
  Future<ResolveResult> resolve(ResolveRequest request) async {
    if (!canResolve(request.ref)) {
      throw ResolverException.unsupported(
        request.ref,
        reason: 'resolver ${descriptor.id} does not serve ${request.ref.kind.name}',
      );
    }

    final MediaTicket ticket;
    try {
      ticket = await _guard(capability.resolve(request.ref, quality: _selectionFor(request.context.preferredQuality)));
    } on ResolverException {
      rethrow;
    } on TimeoutException {
      // A distinct code, because a timeout is retryable and a refusal is not: the ladder that reads this
      // must keep looking for the same content rather than mark it unresolvable.
      throw ResolverException.timedOut(request.ref, timeout);
    } catch (error) {
      throw ResolverException.failed(request.ref.contentId, error);
    }

    final now = (clock ?? _utcNow)();
    if (ticket.isExpiredAt(now)) {
      // Handing over a dead ticket would look like success here and fail inside the player, where the
      // recovery ladder has no way back to a different source.
      throw ResolverException.expired(ticket.id);
    }

    return ResolveResult(
      source: request.ref,
      tickets: <MediaTicket>[ticket],
      createdAt: now,
      selection: MediaSelectionPolicy(
        preferredQuality: request.context.preferredQuality,
        preferredProtocol: ticket.protocol,
      ),
      metadata: <String, Object?>{'platform.resolver': descriptor.id},
    );
  }

  /// Applies [timeout] to a provider call and turns the sdk's [TimeoutException] into the contract's
  /// classified failure, because a caller branches on the code and cannot see an sdk exception type.
  Future<T> _guard<T>(Future<T> operation) => timeout == Duration.zero ? operation : operation.timeout(timeout);

  static SelectionRef? _selectionFor(String? quality) => quality == null ? null : SelectionRef(quality);

  static DateTime _utcNow() => DateTime.now().toUtc();
}

/// Replaces a ticket through the capability that issued it (platform-contracts.md section 14).
///
/// The contract's sketch takes only the expired ticket; the reason is added because the platform's
/// RefreshReason distinguishes "expiring" from "403" from "user asked", and a source that knows which of
/// those it is can pick a different line instead of the same dead one.
final class CapabilityTicketRefresher {
  const CapabilityTicketRefresher(this.capability, {this.timeout = CapabilityResolver.kDefaultResolveTimeout});

  final ResolveCapability capability;

  /// The same budget a first resolve gets: a refresh happens while the player is already running, so a hung
  /// provider here shows up as audio continuing over a frozen or black picture rather than as a failure.
  final Duration timeout;

  /// Refreshable means the platform is allowed to try *and* the source did not say the url is one-shot.
  bool canRefresh(MediaTicket ticket) => ticket.policy.allowRefresh && (ticket.refresh?.supported ?? true);

  Future<MediaTicket> refresh(MediaTicket ticket, RefreshReason reason) async {
    if (!canRefresh(ticket)) {
      throw ResolverException(
        PlatformErrorInfo(
          code: PlatformErrorCodes.permissionRestricted,
          message: 'ticket ${ticket.id} cannot be refreshed by this source',
          category: PlatformErrorCategory.media,
        ),
      );
    }
    try {
      final operation = capability.refresh(ticket, reason);
      return timeout == Duration.zero ? await operation : await operation.timeout(timeout);
    } on ResolverException {
      rethrow;
    } on TimeoutException {
      throw ResolverException(
        PlatformErrorInfo(
          code: PlatformErrorCodes.resolverTimeout,
          message: 'refreshing ticket ${ticket.id} exceeded ${timeout.inSeconds}s',
          category: PlatformErrorCategory.timeout,
          retryable: true,
          recoverable: true,
        ),
      );
    } catch (error) {
      // A refresh is a re-resolve of the same content, so its failure carries the ticket it replaced.
      throw ResolverException.failed(ticket.id, error);
    }
  }
}
