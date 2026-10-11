// Module: lib/src/api/huya_viewer_uid.dart
// Purpose: The anonymous viewer identity the huya CDN accepts in a signed anti-code.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md's anonymous path. Provenance: the v1-maintained huya line's rotl64 naming and
// the uid band the web player issues; this is a fresh implementation, not a merge (UPSTREAM_REVIEW_POLICY.md).

import 'dart:math';

/// Huya's web player names this operation `rotl64`: only the low 32-bit lane is
/// rotated while the upper lane of the 64-bit viewer uid is preserved.
/// Rotating only the low lane and returning it would truncate real anonymous
/// uids (> 2^32) and the CDN answers with 403.
int rotateViewerUid32(int value) {
  final low = value & 0xffffffff;
  final high = value - low;
  final rotatedLow = ((low << 8) | (low >> 24)) & 0xffffffff;
  return high | rotatedLow;
}

/// An anonymous viewer uid in the range the web player issues. Random.nextInt
/// only supports ranges up to 2^32, so the 100-billion offset is composed from
/// two supported uniform draws.
int createFallbackViewerUid() {
  final random = Random.secure();
  final offset = random.nextInt(1000000) * 100000 + random.nextInt(100000);
  return 1400000000000 + offset;
}
