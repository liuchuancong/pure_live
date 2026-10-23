// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_area.g.dart';

/// An area (category node) a room or directory belongs to.
///
/// Parent grouping rides along in [parentAreaId]/[parentAreaName], so
/// callers never need to know each site's nesting depth. Platforms whose
/// area ids are only unique inside a namespace normalize that in their own
/// parser (ARCHITECTURE.md §7.4).
abstract class LiveArea implements Built<LiveArea, LiveAreaBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveArea([void Function(LiveAreaBuilder)? updates]) = _$LiveArea;

  /// The normalized-fields constructor; construct through
  /// [LiveArea.normalized] unless the caller normalized upstream.
  /// The normalized-fields constructor; construct through
  /// [LiveArea.normalized] unless the caller normalized upstream.
  factory LiveArea.of({
    String platform = '',
    String areaId = '',
    String areaName = '',
    String? parentAreaId,
    String? parentAreaName,
    String? iconUrl,
    String? shortName,
    int? position,
  }) => LiveArea(
    (b) => b
      ..platform = platform
      ..areaId = areaId
      ..areaName = areaName
      ..parentAreaId = parentAreaId
      ..parentAreaName = parentAreaName
      ..iconUrl = iconUrl
      ..shortName = shortName
      ..position = position,
  );

  LiveArea._();

  /// Deserializes a stored JSON record.
  factory LiveArea.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveArea.serializer, json)!;

  /// Adapter entry point: normalizes identity fields once and delegates.
  factory LiveArea.normalized({
    String platform = '',
    String areaId = '',
    String areaName = '',
    String? parentAreaId,
    String? parentAreaName,
    String? iconUrl,
    String? shortName,
    int? position,
  }) => LiveArea.of(
    platform: platform.trim().toLowerCase(),
    areaId: areaId.trim(),
    areaName: areaName.trim(),
    parentAreaId: parentAreaId?.trim(),
    parentAreaName: parentAreaName?.trim(),
    iconUrl: iconUrl?.trim(),
    shortName: shortName?.trim(),
    position: position,
  );

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveAreaBuilder b) => b
    ..platform = ''
    ..areaId = ''
    ..areaName = '';

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveArea> get serializer => _$liveAreaSerializer;

  /// The platform the area belongs to, normalized lowercase.
  String get platform;

  /// The area's platform id, unique per platform.
  String get areaId;

  /// The area's display name.
  String get areaName;

  /// The parent group's id, when the platform nests areas.
  String? get parentAreaId;

  /// The parent group's display name.
  String? get parentAreaName;

  /// The area's icon.
  String? get iconUrl;

  /// A shorter display name, when the platform offers one.
  String? get shortName;

  /// The area's sort position.
  int? get position;
}

/// Identity accessor for [LiveArea].
extension LiveAreaIdentity on LiveArea {
  /// Stable collection identity: `platform:areaId`.
  String get identityKey => '$platform:$areaId';
}
