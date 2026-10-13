// The converter constructor spells its class name; the shorthand cannot.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';

/// A room's broadcast state. Stored by **index** in room JSON, so the order
/// must never change; new states are only appended.
enum LiveStatus {
  /// Broadcasting now.
  live,

  /// Not broadcasting.
  offline,

  /// Playing a recording or replay: playable, but not a live broadcast. A
  /// replay the platform gives no stream for carries a `unplayable`
  /// restriction.
  replay,

  /// Not known (no platform evidence, or the last request failed).
  unknown,

  /// Banned or closed by the platform.
  banned,

  /// Looping old videos while the streamer is off (Bilibili's carousel).
  /// Grouped with offline and not playable.
  carousel,
}

/// Reads/writes a [LiveStatus] by its index, matching the stored room JSON.
class LiveStatusIndexConverter extends JsonConverter<LiveStatus, int> {
  /// The converter.
  const LiveStatusIndexConverter();

  @override
  LiveStatus fromJson(int json) =>
      json >= 0 && json < LiveStatus.values.length ? LiveStatus.values[json] : LiveStatus.unknown;

  @override
  int toJson(LiveStatus object) => object.index;
}
