import 'package:freezed_annotation/freezed_annotation.dart';

part 'iptv_models.freezed.dart';
part 'iptv_models.g.dart';

/// The wire format a playlist entry plays.
enum IptvStreamType {
  /// HLS.
  hls,

  /// HTTP-FLV.
  flv,

  /// Whatever else the URL is (mp4, ts, a plugin scheme).
  other,
}

/// One channel entry as parsed from a playlist.
///
/// Headers carry the `#EXTVLCOPT`/`#KODIPROP`/`url|k=v` requests the
/// playlist declared; the catchup fields drive time-shift URL building
/// later.
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
    @Default(<String, String>{}) Map<String, String> headers,
    @Default(<String>[]) List<String> alternatives,
    String? catchupSource,
    String? catchupMode,
    String? catchupDays,
  }) = _IptvEntry;

  /// Restores an entry from JSON.
  factory IptvEntry.fromJson(Map<String, Object?> json) => _$IptvEntryFromJson(json);
}

/// A channel as the library holds it: the parsed entry plus the user's
/// own state.
///
/// [id] is stable across re-imports (the importer reconciles by URL, so
/// favourites, hiding and ordering survive a playlist update).
@freezed
abstract class IptvChannel with _$IptvChannel {
  /// A library channel record.
  const factory IptvChannel({
    required String id,
    required IptvEntry entry,
    @Default(false) bool favorite,
    @Default(false) bool hidden,
    @Default(0) int position,
  }) = _IptvChannel;

  /// Restores a channel from JSON.
  factory IptvChannel.fromJson(Map<String, Object?> json) => _$IptvChannelFromJson(json);
}

/// A playlist source the user imported.
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

/// The stream type a URL maps to.
IptvStreamType streamTypeOf(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.m3u8')) {
    return IptvStreamType.hls;
  }
  if (path.endsWith('.flv')) {
    return IptvStreamType.flv;
  }
  return IptvStreamType.other;
}
