// Module: lib/src/lib/src/models/content/refresh_reason/refresh_reason.dart
// Purpose: Why a ticket is being renewed.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md. Split out of the file that bundled it: one public
// type per file, and the file lives in a folder of its own (§2.1) so a model and anything generated
// for it are found in one place.

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

/// A quality or line choice inside one source's own vocabulary.
