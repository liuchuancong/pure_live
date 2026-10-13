import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'iptv_channel_source.freezed.dart';

/// One playable line of an IPTV channel, already health-ranked by the
/// library that produced it.
@freezed
abstract class IptvLine with _$IptvLine {
  /// Creates a line with already-normalized fields.
  const factory IptvLine({required String url, @Default({}) Map<String, String> headers, String? lineLabel}) =
      _IptvLine;
}

/// One IPTV channel as the site layer sees it: everything a room needs to
/// list, zap to and play the channel.
///
/// This is the seam between `live_iptv` (which owns channels, EPG and line
/// health) and the `iptv` platform adapter in this package (MODELS.md §6):
/// the library side implements [IptvChannelSource], the site side consumes
/// it. Hidden channels stay out of [IptvChannelSource.channels] — a viewer
/// hiding a channel asks not to be offered it — while `channelById` still
/// answers for a room that already holds the id.
@freezed
abstract class IptvChannel with _$IptvChannel {
  /// Creates a channel with already-normalized fields.
  const factory IptvChannel({
    required String id,
    required String name,
    required String url,
    String? group,
    @Default({}) Map<String, String> headers,
    String? epgChannelId,
    @Default(false) bool favorite,
    int? number,
    @Default([]) List<IptvLine> lines,
  }) = _IptvChannel;
}

/// The channel list `live_iptv`'s library exposes to the IPTV site.
abstract interface class IptvChannelSource {
  /// The channels in zap order: the order a screen lists and a remote steps
  /// through.
  List<IptvChannel> get channels;

  /// The channel with [id], looked up regardless of visibility; null when
  /// the id names nothing.
  IptvChannel? channelById(String id);
}
