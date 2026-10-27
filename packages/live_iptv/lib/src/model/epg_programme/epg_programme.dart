// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'epg_programme.g.dart';

/// One programme of a guide channel.
///
/// The times are stored in UTC: guides disagree about zones — XMLTV spells
/// them in attributes, JSON guides in ISO strings with or without an offset
/// — and a stored local time would be wrong the moment the viewer travels.
abstract class EpgProgramme implements Built<EpgProgramme, EpgProgrammeBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory EpgProgramme([void Function(EpgProgrammeBuilder)? updates]) = _$EpgProgramme;

  /// A programme.
  factory EpgProgramme.of({
    required String channelId,
    required DateTime start,
    required DateTime stop,
    String sourceId = '',
    String title = '',
    String? subtitle,
    String? description,
    String? category,
    String? episodeNum,
    String? catchupId,
  }) => EpgProgramme(
    (b) => b
      ..channelId = channelId
      ..start = start
      ..stop = stop
      ..sourceId = sourceId
      ..title = title
      ..subtitle = subtitle
      ..description = description
      ..category = category
      ..episodeNum = episodeNum
      ..catchupId = catchupId,
  );

  EpgProgramme._();

  /// Restores a programme from JSON.
  factory EpgProgramme.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(EpgProgramme.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(EpgProgrammeBuilder b) => b
    ..sourceId = ''
    ..title = '';

  /// The serializer built_value registers in [serializers].
  static Serializer<EpgProgramme> get serializer => _$epgProgrammeSerializer;

  /// The guide channel this programme belongs to (its `channelId`).
  String get channelId;

  /// When it starts, in UTC.
  DateTime get start;

  /// When it stops, in UTC.
  DateTime get stop;

  /// The source the guide came from.
  String get sourceId;

  /// Its title.
  String get title;

  /// Its subtitle, when the guide has one.
  String? get subtitle;

  /// Its description.
  String? get description;

  /// Its category or genre.
  String? get category;

  /// The episode number, in whatever form the guide writes it.
  String? get episodeNum;

  /// The provider's id for replaying this programme, when the guide
  /// carries one; catch-up with `vod`-style modes needs it.
  String? get catchupId;

  /// Serializes this programme for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(EpgProgramme.serializer, this)! as Map<String, Object?>;
}

/// The guide entry the viewer-facing lookups are written against:
/// [EpgProgramme] under its playback name.
///
/// The parsers and the library speak of programmes; the guide a player
/// holds hands the same record back as its entries. One record, two names,
/// so the lookups on `EpgGuide` never have to convert a whole guide to be
/// useful.
typedef EpgEntry = EpgProgramme;
