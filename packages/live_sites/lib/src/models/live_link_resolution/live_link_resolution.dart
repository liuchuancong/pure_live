// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// What a platform made of a link that needs requests to resolve. A sealed
/// family: [LiveLinkRoom] and [LiveLinkRedirect] are its cases.
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
