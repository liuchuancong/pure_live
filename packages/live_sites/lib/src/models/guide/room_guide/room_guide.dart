import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/guide/guide_catch_up/guide_catch_up.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_guide.freezed.dart';
part 'room_guide.g.dart';

/// The IPTV side of a room: which EPG channel it is, what is on air, and how
/// its media requests must be sent.
///
/// [httpHeaders] (Referer, User-Agent, cookies) are per-channel request
/// requirements, normalized; they belong to the channel, not to the player.
@freezed
abstract class RoomGuide with _$RoomGuide {
  /// Creates a RoomGuide with already-normalized fields.
  const factory RoomGuide({
    String? epgId,
    @Default('') String currentProgramme,
    String? currentProgrammeDescription,
    @Default(GuideCatchUp()) GuideCatchUp catchUp,
    @Default({}) Map<String, String> httpHeaders,
  }) = _RoomGuide;

  const RoomGuide._();

  /// Deserializes a stored JSON record.
  factory RoomGuide.fromJson(Map<String, Object?> json) => _$RoomGuideFromJson(json);

  /// A time-shifted programme is currently playing.
  bool get isCatchUpActive => catchUp.isActive;

  /// The same guide without the played catch-up interval.
  RoomGuide withoutCatchUpInterval() => RoomGuide(
    epgId: epgId,
    currentProgramme: currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription,
    catchUp: catchUp.withoutInterval(),
    httpHeaders: httpHeaders,
  );
}
