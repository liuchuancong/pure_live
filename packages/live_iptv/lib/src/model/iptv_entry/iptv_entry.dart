import 'package:freezed_annotation/freezed_annotation.dart';

part 'iptv_entry.freezed.dart';
part 'iptv_entry.g.dart';

/// One channel entry as parsed from a playlist.
///
/// Headers carry the `#EXTVLCOPT`/`#KODIPROP`/`url|k=v` requests the
/// playlist declared; the catchup fields drive time-shift URL building
/// later.
///
/// [channelNumber] is the number the *provider* wrote (`tvg-chno`): a hint,
/// not the user's own — the library turns it into `IptvChannel.number`, which
/// is what a remote control types, and which survives the next playlist
/// coming back without the attribute.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class IptvEntry with _$IptvEntry {
  /// A parsed channel entry.
  const factory IptvEntry({
    required String name,
    required String url,
    String? group,
    String? tvgId,
    String? tvgLogo,
    int? channelNumber,
    @Default(<String, String>{}) Map<String, String> headers,
    @Default(<String>[]) List<String> alternatives,
    String? catchupSource,
    String? catchupMode,
    String? catchupDays,
  }) = _IptvEntry;

  /// Restores an entry from JSON.
  factory IptvEntry.fromJson(Map<String, Object?> json) => _$IptvEntryFromJson(json);
}
