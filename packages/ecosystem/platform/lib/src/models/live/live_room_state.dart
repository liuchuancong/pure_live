// Module: lib/src/models/live/live_room_state.dart
// Purpose: Whether a live room is on air, as the source reported it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1's live status polling; docs/sources/live/source-contract.md.
// `unknown` exists because the failure mode it replaces was real: a poll that timed out read as "ended" makes a
// follow list stop watching a stream that is live, silently.

/// Whether a live room is streaming now.
enum LiveRoomState {
  /// On air.
  live,

  /// The broadcast finished; the item may still be playable as a recording.
  ended,

  /// Scheduled but not started. Distinct from [ended]: a scheduled room is expected to change state, and a
  /// reminder is a reasonable thing to offer on it.
  notStarted,

  /// The source could not tell - a timeout, an unrecognised id, a page that did not carry the flag. Not "off
  /// air", and a surface must not render it as such.
  unknown,
}
