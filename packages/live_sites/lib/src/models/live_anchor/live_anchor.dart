import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_anchor.freezed.dart';

/// A streamer, live or not.
///
/// Separate from a room on purpose, because the two answer different
/// questions: a room is somewhere to watch, an anchor is somebody to follow.
/// Search on several platforms returns *people* — including the ones who are
/// not broadcasting — and modelling them as rooms with an empty stream would
/// mean inventing a room id for someone who has none. The link between the
/// two, when there is one, is [roomId]: an anchor who is on air can be opened
/// as that room.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveAnchor with _$LiveAnchor {
  /// An anchor.
  const factory LiveAnchor({
    /// The platform's user id.
    required String id,

    /// The room to open, when the platform names one; null for an anchor who
    /// has no room yet (or whose room the search does not report).
    String? roomId,

    /// The display name.
    @Default('') String name,

    /// The avatar image.
    String? avatar,

    /// The area the anchor broadcasts in, when the platform says.
    String? areaName,

    /// Whether the anchor is broadcasting right now; null when the platform
    /// does not say (which is not the same as "offline").
    bool? live,

    /// The follower or audience count the platform reports, in whichever unit
    /// it uses.
    int? count,

    /// A one-line introduction, when the platform sends one.
    String? bio,
  }) = _LiveAnchor;
}
