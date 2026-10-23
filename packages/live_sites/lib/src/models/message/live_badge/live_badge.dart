// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_badge.g.dart';

/// One badge image worn next to a sender's name, or attached to a room.
///
/// [id] is the platform's own badge identifier (17live `styleID`), `''` when
/// it has none — the URL is what rendering needs, the id is what equality
/// and caching want.
abstract class LiveBadge implements Built<LiveBadge, LiveBadgeBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveBadge([void Function(LiveBadgeBuilder)? updates]) = _$LiveBadge;

  /// Creates a LiveBadge with already-normalized fields.
  factory LiveBadge.of({required String url, String id = ''}) => LiveBadge(
    (b) => b
      ..url = url
      ..id = id,
  );

  LiveBadge._();

  /// Deserializes a stored JSON record.
  factory LiveBadge.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveBadge.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveBadge> get serializer => _$liveBadgeSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveBadgeBuilder b) => b..id = '';

  /// Where the badge's picture lives.
  String get url;

  /// The platform's own badge identifier, `''` when it has none.
  String get id;
}
