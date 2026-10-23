// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/guide/guide_catch_up/guide_catch_up.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_guide.g.dart';

/// The IPTV side of a room: which EPG channel it is, what is on air, and how
/// its media requests must be sent.
///
/// [httpHeaders] (Referer, User-Agent, cookies) are per-channel request
/// requirements, normalized; they belong to the channel, not to the player.
abstract class RoomGuide implements Built<RoomGuide, RoomGuideBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomGuide([void Function(RoomGuideBuilder)? updates]) = _$RoomGuide;

  /// Creates a RoomGuide with already-normalized fields.
  /// Creates a RoomGuide with already-normalized fields.
  factory RoomGuide.of({
    String? epgId,
    String currentProgramme = '',
    String? currentProgrammeDescription,
    GuideCatchUp? catchUp,
    Map<String, String> httpHeaders = const {},
  }) => RoomGuide(
    (b) => b
      ..epgId = epgId
      ..currentProgramme = currentProgramme
      ..currentProgrammeDescription = currentProgrammeDescription
      ..catchUp.replace(catchUp ?? GuideCatchUp())
      ..httpHeaders.replace(httpHeaders),
  );

  RoomGuide._();

  /// Deserializes a stored JSON record.
  factory RoomGuide.fromJson(Map<String, Object?> json) => serializers.deserializeWith(RoomGuide.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(RoomGuideBuilder b) => b
    ..currentProgramme = ''
    ..catchUp.replace(GuideCatchUp());

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomGuide> get serializer => _$roomGuideSerializer;

  /// The channel's id in the EPG source.
  String? get epgId;

  /// What is on air now.
  String get currentProgramme;

  /// The programme's own description, when the EPG carries one.
  String? get currentProgrammeDescription;

  /// The catch-up (time-shift) facts of the channel.
  GuideCatchUp get catchUp;

  /// Per-channel request requirements (Referer, User-Agent, cookies).
  BuiltMap<String, String> get httpHeaders;

  /// A time-shifted programme is currently playing.
  bool get isCatchUpActive => catchUp.isActive;

  /// The same guide without the played catch-up interval.
  RoomGuide withoutCatchUpInterval() => RoomGuide.of(
    epgId: epgId,
    currentProgramme: currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription,
    catchUp: catchUp.withoutInterval(),
    httpHeaders: httpHeaders.toMap(),
  );
}
