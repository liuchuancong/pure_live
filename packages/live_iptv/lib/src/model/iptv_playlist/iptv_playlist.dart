import 'package:freezed_annotation/freezed_annotation.dart';

part 'iptv_playlist.freezed.dart';
part 'iptv_playlist.g.dart';

/// A playlist source the user imported.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class IptvPlaylist with _$IptvPlaylist {
  /// A playlist record; [url] is set for remote playlists, else the
  /// content lives next to the user's own files.
  const factory IptvPlaylist({
    required String id,
    required String name,
    required DateTime importedAt,
    String? url,
    @Default(0) int channelCount,
  }) = _IptvPlaylist;

  /// Restores a playlist from JSON.
  factory IptvPlaylist.fromJson(Map<String, Object?> json) => _$IptvPlaylistFromJson(json);
}
