// Freezed factories cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';

part 'catch_up.freezed.dart';
part 'catch_up.g.dart';

/// Catch-up (time-shift) playback of a channel.
@freezed
abstract class CatchUp with _$CatchUp {
  /// Creates the catch-up state.
  const factory CatchUp({
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
  }) = _CatchUp;

  const CatchUp._();

  /// Reads a stored catch-up record.
  factory CatchUp.fromJson(Map<String, Object?> json) => _$CatchUpFromJson(json);

  /// Whether a time-shifted programme is playing (flag or URL present).
  bool get isActive => active || (url?.trim().isNotEmpty ?? false);

  /// The provider settings without the played interval (back to live).
  CatchUp withoutInterval() => CatchUp(mode: mode, source: source, days: days, correctionHours: correctionHours);
}

/// Everything IPTV-like about a room: the guide channel and programme on air,
/// the catch-up (time-shift) state, and the headers its media requests need.
///
/// These fields belong together — a plain live room has none — so the room
/// holds one `LiveGuide` rather than five loose IPTV fields. [httpHeaders] is
/// normalized (lower-cased names); it comes from the playlist, not a platform
/// response.
@immutable
final class LiveGuide {
  /// Creates the IPTV guide state.
  const LiveGuide({
    this.epgId,
    this.currentProgramme = '',
    this.currentProgrammeDescription,
    this.catchUp = const CatchUp(),
    this.httpHeaders = const {},
  });

  /// Guide channel id.
  final String? epgId;

  /// Programme on air.
  final String currentProgramme;

  /// Description of the programme on air.
  final String? currentProgrammeDescription;

  /// Catch-up (time-shift) playback.
  final CatchUp catchUp;

  /// Headers the channel's media requests need, normalized.
  final Map<String, String> httpHeaders;

  /// Whether a time-shifted programme is playing.
  bool get isCatchUpActive => catchUp.isActive;

  /// The guide with the played catch-up interval removed (back to live), so a
  /// later guide render never highlights a retired programme.
  LiveGuide withoutCatchUpInterval() => LiveGuide(
    epgId: epgId,
    currentProgramme: currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription,
    catchUp: catchUp.withoutInterval(),
    httpHeaders: httpHeaders,
  );

  @override
  String toString() => 'LiveGuide($epgId, $currentProgramme)';
}
