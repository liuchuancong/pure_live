import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_links.freezed.dart';
part 'room_links.g.dart';

/// How to reach a room outside the app: the web page, the platform's
/// app-launch scheme, and a share short link.
///
/// `appUrl` launches the platform's own app (`bilibili://live/23058`);
/// `shareUrl` is a platform-generated promotional link. All nullable — a
/// room may have none of these.
@freezed
abstract class RoomLinks with _$RoomLinks {
  /// Creates a RoomLinks with already-normalized fields.
  const factory RoomLinks({String? webUrl, String? appUrl, String? shareUrl}) = _RoomLinks;

  /// Deserializes a stored JSON record.
  factory RoomLinks.fromJson(Map<String, Object?> json) => _$RoomLinksFromJson(json);
}
