// Module: lib/src/models/content/refresh_reason/refresh_reason.dart
// Purpose: Why a ticket is being renewed.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

/// Why a ticket is being refreshed.
///
/// Spec: docs/contracts/media-contract.md section 3 and docs/media/media-ticket.md section 2 list these
/// names; docs/architecture/evolution.md forbids renaming or reordering an enum once it exists, so the
/// documented set is used as written instead of a reduced local one. The four failure causes stay separate
/// because the recovery ladder differs per cause (docs/media/recovery.md).
enum RefreshReason {
  expiring,
  expired,
  networkError,
  http403,
  http404,
  decodeError,
  manual,
  qualityChanged,
  lineChanged,
}
