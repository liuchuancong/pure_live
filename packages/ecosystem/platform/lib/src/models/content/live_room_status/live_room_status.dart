// Module: lib/src/models/content/live_room_status/live_room_status.dart
// Purpose: The cheap, pollable answer about one room: is it on air, and what does it look like right now.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (live status polling).
//
// Generated shape on purpose (package-architecture.md §2.1): this is a model **we** own - our storage, our
// polling, our wire - so freezed gives it equality, copyWith and toString without hand-rolled code that can
// forget a field. The models that stay hand-written are the ones adapting somebody else's wire format, where
// the tolerance rules *are* the implementation (ContentSummary, MediaTicket); a generated `fromJson` there
// would either lose them or hide them behind converters nobody can read at a glance.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../content_ref.dart';
import '../live_room_state.dart';

part 'live_room_status.freezed.dart';
part 'live_room_status.g.dart';

/// One room's current state.
@freezed
abstract class LiveRoomStatus with _$LiveRoomStatus {
  const factory LiveRoomStatus({
    required ContentRef ref,

    /// [LiveRoomState.unknown] is "the source could not tell" and is deliberately not collapsed into
    /// [LiveRoomState.ended]: a follow list that reads a timeout as off-air stops watching a live stream.
    required LiveRoomState state,

    /// Viewer count exactly as the platform worded it. The unit (concurrent viewers, total visits, heat) is
    /// the source's own, so this model does not rename it; a surface that shows it carries the platform's label.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,
    String? title,
    String? cover,
    String? anchorName,

    /// When the broadcast started, when the source says so.
    DateTime? startedAt,
  }) = _LiveRoomStatus;

  const LiveRoomStatus._();

  factory LiveRoomStatus.fromJson(Map<String, Object?> json) => _$LiveRoomStatusFromJson(json);

  bool get isLive => state == LiveRoomState.live;
}

/// Accepts the number-or-string shape the platforms send, and reads anything else as "not stated".
int? _intOrNull(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};
