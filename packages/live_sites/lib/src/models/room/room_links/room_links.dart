// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_links.g.dart';

/// How to reach a room outside the app: the web page, the platform's
/// app-launch scheme, and a share short link.
///
/// `appUrl` launches the platform's own app (`bilibili://live/23058`);
/// `shareUrl` is a platform-generated promotional link. All nullable — a
/// room may have none of these.
abstract class RoomLinks implements Built<RoomLinks, RoomLinksBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomLinks([void Function(RoomLinksBuilder)? updates]) = _$RoomLinks;

  /// Creates a RoomLinks with already-normalized fields.
  /// Creates a RoomLinks with already-normalized fields.
  factory RoomLinks.of({String? webUrl, String? appUrl, String? shareUrl}) => RoomLinks(
    (b) => b
      ..webUrl = webUrl
      ..appUrl = appUrl
      ..shareUrl = shareUrl,
  );

  RoomLinks._();

  /// Deserializes a stored JSON record.
  factory RoomLinks.fromJson(Map<String, Object?> json) => serializers.deserializeWith(RoomLinks.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomLinks> get serializer => _$roomLinksSerializer;

  /// The room's web page.
  String? get webUrl;

  /// The platform's app-launch scheme for the room.
  String? get appUrl;

  /// A platform-generated promotional link.
  String? get shareUrl;
}
