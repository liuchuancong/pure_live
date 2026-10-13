// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// How to reach a room: its web page and its app-launch scheme.
///
/// [link] is the browser URL; [nativeLink] is the platform's own deep-link
/// scheme (for example `bilibili://live/23058`) that opens the room inside the
/// platform's app. A room may have either, both, or neither.
@immutable
final class LiveRoomLinks {
  /// Creates the links for a room.
  const LiveRoomLinks({this.link, this.nativeLink});

  /// Web link to the room.
  final String? link;

  /// The platform's app-launch scheme for the room; null when it gives none.
  final String? nativeLink;

  @override
  String toString() => 'LiveRoomLinks(link: $link, nativeLink: $nativeLink)';
}
