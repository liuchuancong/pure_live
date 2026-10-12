import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_iptv/src/model/iptv_entry/iptv_entry.dart';

part 'iptv_channel.freezed.dart';
part 'iptv_channel.g.dart';

/// A channel as the library holds it: the parsed entry plus the user's
/// own state.
///
/// [id] is stable across re-imports (the importer reconciles by URL, so
/// favourites, hiding and ordering survive a playlist update).
///
/// [number] is the channel's remote-control number, and [pinned] puts it
/// in front of the list whatever its number or group says; both belong to
/// the user rather than to the playlist, which is why they live here and
/// not on [IptvEntry]. A null [number] means the user never gave the
/// channel one, and an unnumbered channel sorts *after* the numbered ones
/// — the alternative, inventing a number for everything, would overwrite
/// the numbers the user typed with ones the importer guessed.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class IptvChannel with _$IptvChannel {
  /// A library channel record.
  const factory IptvChannel({
    required String id,
    required IptvEntry entry,
    @Default(false) bool favorite,
    @Default(false) bool hidden,
    @Default(false) bool pinned,
    @Default(0) int position,
    int? number,
  }) = _IptvChannel;

  /// Restores a channel from JSON.
  factory IptvChannel.fromJson(Map<String, Object?> json) => _$IptvChannelFromJson(json);
}
