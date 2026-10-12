import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_programme.freezed.dart';
part 'epg_programme.g.dart';

/// One programme of a guide channel.
///
/// The times are stored in UTC: guides disagree about zones — XMLTV spells
/// them in attributes, JSON guides in ISO strings with or without an offset
/// — and a stored local time would be wrong the moment the viewer travels.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class EpgProgramme with _$EpgProgramme {
  /// A programme.
  const factory EpgProgramme({
    /// The guide channel this programme belongs to (its `channelId`).
    required String channelId,

    /// When it starts, in UTC.
    required DateTime start,

    /// When it stops, in UTC.
    required DateTime stop,

    /// The source the guide came from.
    @Default('') String sourceId,

    /// Its title.
    @Default('') String title,

    /// Its subtitle, when the guide has one.
    String? subtitle,

    /// Its description.
    String? description,

    /// Its category or genre.
    String? category,

    /// The episode number, in whatever form the guide writes it.
    String? episodeNum,

    /// The provider's id for replaying this programme, when the guide
    /// carries one; catch-up with `vod`-style modes needs it.
    String? catchupId,
  }) = _EpgProgramme;

  /// Restores a programme from JSON.
  factory EpgProgramme.fromJson(Map<String, Object?> json) => _$EpgProgrammeFromJson(json);
}
