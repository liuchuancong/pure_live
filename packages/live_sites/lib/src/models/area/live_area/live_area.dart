import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_area.freezed.dart';
part 'live_area.g.dart';

/// An area (category node) a room or directory belongs to.
///
/// Parent grouping rides along in [parentAreaId]/[parentAreaName], so
/// callers never need to know each site's nesting depth. Platforms whose
/// area ids are only unique inside a namespace normalize that in their own
/// parser (ARCHITECTURE.md §7.4).
@freezed
abstract class LiveArea with _$LiveArea {
  /// The normalized-fields constructor (code generation and copyWith
  /// target); construct through [LiveArea.normalized] unless the caller
  /// normalized upstream.
  const factory LiveArea({
    @Default('') String platform,
    @Default('') String areaId,
    @Default('') String areaName,
    String? parentAreaId,
    String? parentAreaName,
    String? iconUrl,
    String? shortName,
    int? position,
  }) = _LiveArea;

  /// Deserializes a stored JSON record.
  factory LiveArea.fromJson(Map<String, Object?> json) => _$LiveAreaFromJson(json);

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
  }) => LiveArea(
    platform: platform.trim().toLowerCase(),
    areaId: areaId.trim(),
    areaName: areaName.trim(),
    parentAreaId: parentAreaId?.trim(),
    parentAreaName: parentAreaName?.trim(),
    iconUrl: iconUrl?.trim(),
    shortName: shortName?.trim(),
    position: position,
  );
}

/// Identity accessor for [LiveArea].
extension LiveAreaIdentity on LiveArea {
  /// Stable collection identity: `platform:areaId`.
  String get identityKey => '$platform:$areaId';
}
