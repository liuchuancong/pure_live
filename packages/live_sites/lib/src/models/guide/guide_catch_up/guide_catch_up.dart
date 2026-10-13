import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'guide_catch_up.freezed.dart';
part 'guide_catch_up.g.dart';

/// IPTV catch-up (time-shifted) playback: the provider's template facts and
/// the interval currently played.
///
/// Config survives without an interval: [withoutInterval] drops `url`,
/// [active], [start] and [end] while keeping the provider description, so
/// returning to the live stream never leaves a retired programme
/// highlighted.
@freezed
abstract class GuideCatchUp with _$GuideCatchUp {
  /// Creates a GuideCatchUp with already-normalized fields.
  const factory GuideCatchUp({
    String? url,
    @Default(false) bool active,
    int? start,
    int? end,
    String? mode,
    String? urlTemplate,
    double? windowDays,
    double? correctionHours,
    String? catchupId,
  }) = _GuideCatchUp;

  const GuideCatchUp._();

  /// Deserializes a stored JSON record.
  factory GuideCatchUp.fromJson(Map<String, Object?> json) => _$GuideCatchUpFromJson(json);

  /// Playing a time-shifted interval (or one is resolvable).
  bool get isActive => active || (url?.trim().isNotEmpty ?? false);

  /// The same catch-up configuration without the played interval.
  GuideCatchUp withoutInterval() => GuideCatchUp(
    mode: mode,
    urlTemplate: urlTemplate,
    windowDays: windowDays,
    correctionHours: correctionHours,
    catchupId: catchupId,
  );
}
