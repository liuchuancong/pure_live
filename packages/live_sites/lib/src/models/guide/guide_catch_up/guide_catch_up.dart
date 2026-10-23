// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'guide_catch_up.g.dart';

/// IPTV catch-up (time-shifted) playback: the provider's template facts and
/// the interval currently played.
///
/// Config survives without an interval: [withoutInterval] drops `url`,
/// [active], `start` and `end` while keeping the provider description, so
/// returning to the live stream never leaves a retired programme
/// highlighted.
abstract class GuideCatchUp implements Built<GuideCatchUp, GuideCatchUpBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory GuideCatchUp([void Function(GuideCatchUpBuilder)? updates]) = _$GuideCatchUp;

  /// Creates a GuideCatchUp with already-normalized fields.
  /// Creates a GuideCatchUp with already-normalized fields.
  factory GuideCatchUp.of({
    String? url,
    bool active = false,
    int? start,
    int? end,
    String? mode,
    String? urlTemplate,
    double? windowDays,
    double? correctionHours,
    String? catchupId,
  }) => GuideCatchUp(
    (b) => b
      ..url = url
      ..active = active
      ..start = start
      ..end = end
      ..mode = mode
      ..urlTemplate = urlTemplate
      ..windowDays = windowDays
      ..correctionHours = correctionHours
      ..catchupId = catchupId,
  );

  GuideCatchUp._();

  /// Deserializes a stored JSON record.
  factory GuideCatchUp.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(GuideCatchUp.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(GuideCatchUpBuilder b) => b..active = false;

  /// The serializer built_value registers in [serializers].
  static Serializer<GuideCatchUp> get serializer => _$guideCatchUpSerializer;

  /// The provider's resolved catch-up address for this interval.
  String? get url;

  /// A time-shifted interval is playing.
  bool get active;

  /// The interval's start, epoch seconds.
  int? get start;

  /// The interval's end, epoch seconds.
  int? get end;

  /// The provider's catch-up flavour.
  String? get mode;

  /// The URL template the provider resolves intervals against.
  String? get urlTemplate;

  /// How far back the provider serves, in days.
  double? get windowDays;

  /// The provider's clock offset against UTC, in hours.
  double? get correctionHours;

  /// The provider's own catch-up id for the channel.
  String? get catchupId;

  /// Playing a time-shifted interval (or one is resolvable).
  bool get isActive => active || (url?.trim().isNotEmpty ?? false);

  /// The same catch-up configuration without the played interval.
  GuideCatchUp withoutInterval() => GuideCatchUp.of(
    mode: mode,
    urlTemplate: urlTemplate,
    windowDays: windowDays,
    correctionHours: correctionHours,
    catchupId: catchupId,
  );
}
