// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_content.g.dart';

/// A room's display text and imagery: title, cover, introduction, notice,
/// plus platform-side badges and tags.
///
/// [platformTags] are the platform's own room tags — distinct from the local
/// follow tags in `RoomLocal`.
abstract class RoomContent implements Built<RoomContent, RoomContentBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomContent([void Function(RoomContentBuilder)? updates]) = _$RoomContent;

  /// Creates a RoomContent with already-normalized fields.
  /// Creates a RoomContent with already-normalized fields.
  factory RoomContent.of({
    String title = '',
    String coverUrl = '',
    String? introduction,
    String? notice,
    List<LiveBadge> badges = const [],
    List<String> platformTags = const [],
  }) => RoomContent(
    (b) => b
      ..title = title
      ..coverUrl = coverUrl
      ..introduction = introduction
      ..notice = notice
      ..badges.replace(badges)
      ..platformTags.replace(platformTags),
  );

  RoomContent._();

  /// Deserializes a stored JSON record.
  factory RoomContent.fromJson(Map<String, Object?> json) => serializers.deserializeWith(RoomContent.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(RoomContentBuilder b) => b
    ..title = ''
    ..coverUrl = '';

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomContent> get serializer => _$roomContentSerializer;

  /// The room's title.
  String get title;

  /// The room's cover image.
  String get coverUrl;

  /// The streamer's self description of the room.
  String? get introduction;

  /// The room's announcement.
  String? get notice;

  /// The platform's badges on the room.
  BuiltList<LiveBadge> get badges;

  /// The platform's own room tags.
  BuiltList<String> get platformTags;

  /// A sparse refresh merge: blank incoming text never erases stored text.
  RoomContent mergedWith(RoomContent incoming) {
    String prefer(String next, String current) => next.trim().isEmpty ? current : next;
    return rebuild(
      (b) => b
        ..title = prefer(incoming.title, title)
        ..coverUrl = prefer(incoming.coverUrl, coverUrl)
        ..introduction = incoming.introduction?.trim().isEmpty ?? true ? introduction : incoming.introduction
        ..notice = incoming.notice?.trim().isEmpty ?? true ? notice : incoming.notice
        ..badges.replace(incoming.badges.isEmpty ? badges : incoming.badges)
        ..platformTags.replace(incoming.platformTags.isEmpty ? platformTags : incoming.platformTags),
    );
  }
}
