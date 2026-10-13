// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// The per-user local state of a followed room: its tags and the last time it
/// was watched. This is never a platform value — it lives only in the app's
/// follow and history records — so a detail refresh keeps it as-is.
@immutable
final class LiveRoomLocal {
  /// Creates the local follow state.
  const LiveRoomLocal({this.lastWatchedAt, this.tagIds = const []});

  /// Last time this room was watched, epoch milliseconds (history).
  final int? lastWatchedAt;

  /// Tags of a followed room (local only).
  final List<String> tagIds;

  @override
  String toString() => 'LiveRoomLocal(${tagIds.length} tags)';
}
