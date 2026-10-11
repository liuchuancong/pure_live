// Module: lib/src/models/live/live_catch_up/live_catch_up.dart
// Purpose: The room's own statement about time-shift and replay, which the player needs before it can offer either.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: the reference product carries the same object on its room model (`CatchUp` with url/active/start/end/
// mode/source/days/correctionHours). It belongs to live rather than to vod because the window is a property of
// the broadcast: how far back the site lets you rewind, and whether the offset it publishes is in the room's own
// clock or in wall time.
//
// `correctionHours` is not a nicety: a listing published in UTC+8 whose seek url is wall-clock needs the
// difference stated, or "回到 20:00" silently rewinds to 12:00 and the seek - or a recording made from it -
// looks corrupt for reasons nothing on screen explains.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_catch_up.freezed.dart';
part 'live_catch_up.g.dart';

/// What one room offers for watching the part of the broadcast that already happened.
@freezed
abstract class LiveCatchUp with _$LiveCatchUp {
  const factory LiveCatchUp({
    /// Whether this room has time-shift at all. False is an answer, not missing data.
    @Default(false) bool active,

    /// The template or address the site hands out for a rewound stream, when it gives one separately.
    @JsonKey(fromJson: _text) String? url,

    /// The earliest offset the site keeps, in seconds within the available window.
    @JsonKey(fromJson: _seconds, toJson: _seconds) int? start,

    /// The latest offset it will serve, in the same frame as [start].
    @JsonKey(fromJson: _seconds, toJson: _seconds) int? end,

    /// The site's own mode word (`catchup`, `seek`, `timeshift`, `playlist`), kept verbatim because the player
    /// has to build the url the way that mode expects.
    @JsonKey(fromJson: _text) String? mode,

    /// Which endpoint described this window, so a failure traces to one site field instead of to "the room said
    /// something about replay".
    @JsonKey(fromJson: _text) String? source,

    /// How many days back the archive reaches, when the site states it as days.
    @JsonKey(fromJson: _number, toJson: _number) double? days,

    /// The offset between the site's published clock and wall time, in hours. Null means the site never said,
    /// which is not 0: 0 claims the two agree.
    @JsonKey(fromJson: _number, toJson: _number) double? correctionHours,
  }) = _LiveCatchUp;

  const LiveCatchUp._();

  factory LiveCatchUp.fromJson(Map<String, Object?> json) => _$LiveCatchUpFromJson(json);

  /// Whether anything here lets a viewer rewind.
  bool get isOffered => active || (url?.isNotEmpty ?? false) || (mode?.isNotEmpty ?? false);

  /// The rewind window in seconds, when both ends are stated. An inverted pair is not a window: reading it
  /// backwards would let a seek land outside the archive and hang the player.
  int? get windowSeconds {
    final from = start;
    final to = end;
    if (from == null || to == null || to < from) {
      return null;
    }
    return to - from;
  }
}

String? _text(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

int? _seconds(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

double? _number(Object? value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}'.trim());
