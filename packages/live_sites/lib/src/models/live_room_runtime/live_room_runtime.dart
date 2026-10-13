// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// The platform-specific runtime handles a room carries for later steps, never
/// stored to disk.
///
/// [streamData] is what a stream resolver needs (a sign, a room id the play API
/// wants); [danmakuData] is what opening the danmaku connection needs (a token,
/// a numeric id, a socket address). Each adapter defines its own shape.
@immutable
final class LiveRoomRuntime {
  /// Creates the runtime handles.
  const LiveRoomRuntime({this.streamData, this.danmakuData});

  /// Platform data needed to resolve streams; never stored.
  final Object? streamData;

  /// Platform data needed to connect danmaku; never stored.
  final Object? danmakuData;

  @override
  String toString() => 'LiveRoomRuntime()';
}
