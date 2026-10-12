import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_channel.freezed.dart';
part 'epg_channel.g.dart';

/// The storage key of one guide channel.
///
/// `epg:<json [sourceId, channelId]>`, byte for byte what the previous
/// generation wrote: rooms store this key as their guide id, so a different
/// spelling would orphan every saved room's programme list. The JSON array
/// is what keeps the two parts unambiguous — a separator like `:` inside an
/// id cannot fake another key.
String epgChannelKey(String sourceId, String channelId) => 'epg:${jsonEncode([sourceId, channelId])}';

/// One channel of a stored guide.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class EpgChannel with _$EpgChannel {
  /// A stored guide channel.
  const factory EpgChannel({
    /// The source the channel came from.
    required String sourceId,

    /// The guide's own channel id.
    required String channelId,

    /// The name shown when the guide gives no better one.
    @Default('') String displayName,

    /// The channel's icon.
    String? iconUrl,
  }) = _EpgChannel;

  /// Restores a channel from JSON.
  factory EpgChannel.fromJson(Map<String, Object?> json) => _$EpgChannelFromJson(json);
}

/// A room's guide id, as the IPTV site and the library both name it.
extension EpgChannelKeyX on EpgChannel {
  /// The storage key of this channel.
  String get key => epgChannelKey(sourceId, channelId);

  /// The name to show for this channel.
  String get primaryName => displayName.isEmpty ? channelId : displayName;
}
