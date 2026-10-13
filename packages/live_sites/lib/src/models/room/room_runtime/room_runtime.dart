import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_runtime.freezed.dart';

/// The transient handles a platform hands to playback and danmaku.
///
/// A handle is an opaque token only the producing platform code understands;
/// handles are never serialized, never stored, and never passed across
/// platforms. This is a deliberate design decision, not a type hole.
@freezed
abstract class RoomRuntime with _$RoomRuntime {
  /// Creates a RoomRuntime with already-normalized fields.
  const factory RoomRuntime({Object? streamHandle, Object? danmakuHandle}) = _RoomRuntime;
}
