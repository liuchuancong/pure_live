// Module: lib/src/ticket_policy.dart
// Purpose: Translates a MediaTicketPolicy into the kernel's recovery and fallback policies.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-models.md section 11 (what the platform is allowed to do with a ticket) and
// docs/adr/0020-media-core-owns-recovery.md (the kernel owns how it is done). The platform states intent; the
// kernel's policies state attempts and backoff, and those numbers are deliberately left at the kernel's
// defaults because the ticket does not carry them.

import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

/// Recovery policy for one ticket.
core.RecoveryPolicy toRecoveryPolicy(platform.MediaTicketPolicy policy) {
  return core.RecoveryPolicy(
    enabled: policy.allowRetry,
    retryDelay: policy.retryDelay,
    // A ticket that forbids re-resolution has no business reaching for another source either.
    allowSourceFallback: policy.allowRefresh,
    allowBackendFallback: policy.allowEngineFallback,
  );
}

/// Fallback policy for one ticket.
core.FallbackPolicy toFallbackPolicy(platform.MediaTicketPolicy policy) {
  final anyFallback = policy.allowLineFallback || policy.allowEngineFallback;
  return core.FallbackPolicy(
    enabled: anyFallback,
    allowLineFallback: policy.allowLineFallback,
    allowBackendFallback: policy.allowEngineFallback,
    // Quality switching is a source-side choice the platform expresses by re-resolving with a different
    // SelectionRef, not by falling back inside one playback, so the kernel is not asked to downgrade.
    downgradeQualityOnFailure: false,
  );
}
