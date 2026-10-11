// Module: lib/src/api/huya_profile_request_failure.dart
// Purpose: The named failure for a profileRoom answer that is not a room.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/provider-contract.md (a source reports refusals as their own type). A bare StateError
// saying "status 404" is undiagnosable a week later: a closed room, a deleted room and a risk-control refusal
// all answer there, and the message the endpoint sent is the only thing that tells them apart.

/// profileRoom refused to describe a room.
final class HuyaProfileRequestFailure implements Exception {
  const HuyaProfileRequestFailure(this.roomId, {required this.status, this.message});

  /// The room that was asked about.
  final String roomId;

  /// The endpoint's own status field, as text - `null` in the answer is `'none'`, not a missing field.
  final String status;

  /// The site's message, kept verbatim because that is what distinguishes the three refusals above.
  final String? message;

  @override
  String toString() =>
      'HuyaProfileRequestFailure($roomId answered status $status'
      '${message == null ? '' : ': $message'})';
}
