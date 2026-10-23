// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';

part 'room_runtime.g.dart';

/// The transient handles a platform hands to playback and danmaku.
///
/// A handle is an opaque token only the producing platform code understands;
/// handles are never serialized, never stored, and never passed across
/// platforms. This is a deliberate design decision, not a type hole —
/// which is also why this type carries no serializer.
abstract class RoomRuntime implements Built<RoomRuntime, RoomRuntimeBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomRuntime([void Function(RoomRuntimeBuilder)? updates]) = _$RoomRuntime;

  /// Creates a RoomRuntime with already-normalized fields.
  /// Creates a RoomRuntime with already-normalized fields.
  factory RoomRuntime.of({Object? streamHandle, Object? danmakuHandle}) => RoomRuntime(
    (b) => b
      ..streamHandle = streamHandle
      ..danmakuHandle = danmakuHandle,
  );

  RoomRuntime._();

  /// The platform's opaque token for the resolved stream.
  Object? get streamHandle;

  /// The platform's opaque token for its danmaku session.
  Object? get danmakuHandle;
}
