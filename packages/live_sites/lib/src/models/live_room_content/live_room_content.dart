// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// The text a room page shows about the broadcast itself: title, cover, the
/// streamer's introduction and the room notice.
///
/// An adapter that does not get a real value leaves it empty rather than
/// filling in a stand-in, so a merge keeps the stored value only against an
/// empty one.
@immutable
final class LiveRoomContent {
  /// Creates the room's display text.
  const LiveRoomContent({this.title = '', this.cover = '', this.introduction, this.notice});

  /// Room title.
  final String title;

  /// Cover URL.
  final String cover;

  /// Room introduction, or null when the response did not give one.
  final String? introduction;

  /// Room notice, or null when the response did not give one.
  final String? notice;

  @override
  String toString() => 'LiveRoomContent($title)';
}
