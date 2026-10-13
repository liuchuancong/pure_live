import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_content.freezed.dart';
part 'room_content.g.dart';

/// A room's display text and imagery: title, cover, introduction, notice,
/// plus platform-side badges and tags.
///
/// [platformTags] are the platform's own room tags — distinct from the local
/// follow tags in `RoomLocal`.
@freezed
abstract class RoomContent with _$RoomContent {
  /// Creates a RoomContent with already-normalized fields.
  const factory RoomContent({
    @Default('') String title,
    @Default('') String coverUrl,
    String? introduction,
    String? notice,
    @Default([]) List<LiveBadge> badges,
    @Default([]) List<String> platformTags,
  }) = _RoomContent;

  const RoomContent._();

  /// Deserializes a stored JSON record.
  factory RoomContent.fromJson(Map<String, Object?> json) => _$RoomContentFromJson(json);

  /// A sparse refresh merge: blank incoming text never erases stored text.
  RoomContent mergedWith(RoomContent incoming) {
    String prefer(String next, String current) => next.trim().isEmpty ? current : next;
    return copyWith(
      title: prefer(incoming.title, title),
      coverUrl: prefer(incoming.coverUrl, coverUrl),
      introduction: incoming.introduction?.trim().isEmpty ?? true ? introduction : incoming.introduction,
      notice: incoming.notice?.trim().isEmpty ?? true ? notice : incoming.notice,
      badges: incoming.badges.isEmpty ? badges : incoming.badges,
      platformTags: incoming.platformTags.isEmpty ? platformTags : incoming.platformTags,
    );
  }
}
