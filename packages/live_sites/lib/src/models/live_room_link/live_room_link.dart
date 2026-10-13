// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A room a link points to.
@immutable
final class LiveRoomLink {
  /// Creates the link target for [platform]'s room [roomId].
  const LiveRoomLink(this.platform, this.roomId);

  /// Platform id.
  final String platform;

  /// Room id within the platform.
  final String roomId;

  @override
  bool operator ==(Object other) => other is LiveRoomLink && other.platform == platform && other.roomId == roomId;

  @override
  int get hashCode => Object.hash(platform, roomId);

  @override
  String toString() => 'LiveRoomLink($platform, $roomId)';
}
