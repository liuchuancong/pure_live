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

/// What a platform made of a link that needs requests to resolve.
@immutable
sealed class LiveLinkResolution {
  /// A resolution.
  const LiveLinkResolution();
}

/// The link points to [roomId].
final class LiveLinkRoom extends LiveLinkResolution {
  /// Creates the result.
  const LiveLinkRoom(this.roomId);

  /// Room id within the platform.
  final String roomId;
}

/// The link redirects to [target], which is parsed again (by any platform).
final class LiveLinkRedirect extends LiveLinkResolution {
  /// Creates the result.
  const LiveLinkRedirect(this.target);

  /// Where the short link leads.
  final Uri target;
}
