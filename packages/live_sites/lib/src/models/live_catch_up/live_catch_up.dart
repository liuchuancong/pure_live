// Freezed factories cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_catch_up.freezed.dart';
part 'live_catch_up.g.dart';

/// Catch-up (time-shift) playback of a channel.
@freezed
abstract class LiveCatchUp with _$LiveCatchUp {
  /// Creates the catch-up state.
  const factory LiveCatchUp({
    /// Time-shifted stream URL of the programme being played, if any.
    String? url,

    /// Whether a time-shifted programme is playing.
    @Default(false) bool active,

    /// Start of the played interval, epoch milliseconds.
    int? start,

    /// End of the played interval, epoch milliseconds.
    int? end,

    /// The playlist provider's catch-up mode (`default`, `append`, `shift`).
    String? mode,

    /// The provider's URL template or query.
    String? source,

    /// How many days the provider keeps.
    double? days,

    /// Correction for the provider's timestamps, in hours.
    double? correctionHours,
  }) = _LiveCatchUp;

  const LiveCatchUp._();

  /// Reads a stored catch-up record.
  factory LiveCatchUp.fromJson(Map<String, Object?> json) => _$LiveCatchUpFromJson(json);

  /// Whether a time-shifted programme is playing (flag or URL present).
  bool get isActive => active || (url?.trim().isNotEmpty ?? false);

  /// The provider settings without the played interval (back to live).
  LiveCatchUp withoutInterval() =>
      LiveCatchUp(mode: mode, source: source, days: days, correctionHours: correctionHours);
}
