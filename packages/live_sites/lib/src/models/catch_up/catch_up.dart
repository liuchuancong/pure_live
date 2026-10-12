import 'package:freezed_annotation/freezed_annotation.dart';

part 'catch_up.freezed.dart';

/// A past broadcast of a room: the part of a room's history that is *not* the
/// room.
///
/// The reason this is its own model rather than a room field: a catch-up
/// entry has an id from a different namespace than the room id (a video id, a
/// session id), a start and end time of its own, and it stays playable while
/// the room itself is offline. Treating it as "the room, but old" is how a
/// client ends up requesting a live stream for a room that closed days ago —
/// the request that made catch-up look broken everywhere it was bolted onto
/// the room model.
///
/// A site that offers catch-up therefore returns these alongside the room,
/// and resolving one goes through the room (which carries the platform and
/// the session context) plus the entry's own [id] — never through the room id
/// alone.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class CatchUpEntry with _$CatchUpEntry {
  /// A past broadcast.
  const factory CatchUpEntry({
    /// The platform's id for this broadcast; not a room id.
    required String id,

    /// The room it belongs to.
    required String roomId,

    /// The title the platform gave the broadcast.
    @Default('') String title,

    /// When it started, when the platform says.
    DateTime? startedAt,

    /// When it ended, when the platform says.
    DateTime? endedAt,

    /// How long it runs, when the platform says.
    Duration? duration,

    /// The cover image, when the platform gives one.
    String? cover,

    /// The playable address, when the platform embeds one; null means it has
    /// to be resolved through [id].
    String? url,
  }) = _CatchUpEntry;
}
