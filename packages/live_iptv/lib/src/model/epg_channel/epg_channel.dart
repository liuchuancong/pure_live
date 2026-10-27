// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:convert';

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

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
abstract class EpgChannel implements Built<EpgChannel, EpgChannelBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory EpgChannel([void Function(EpgChannelBuilder)? updates]) = _$EpgChannel;

  /// A stored guide channel.
  factory EpgChannel.of({
    required String sourceId,
    required String channelId,
    String displayName = '',
    String? iconUrl,
  }) => EpgChannel(
    (b) => b
      ..sourceId = sourceId
      ..channelId = channelId
      ..displayName = displayName
      ..iconUrl = iconUrl,
  );

  EpgChannel._();

  /// Restores a channel from JSON.
  factory EpgChannel.fromJson(Map<String, Object?> json) => serializers.deserializeWith(EpgChannel.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(EpgChannelBuilder b) => b..displayName = '';

  /// The serializer built_value registers in [serializers].
  static Serializer<EpgChannel> get serializer => _$epgChannelSerializer;

  /// The source the channel came from.
  String get sourceId;

  /// The guide's own channel id.
  String get channelId;

  /// The name shown when the guide gives no better one.
  String get displayName;

  /// The channel's icon.
  String? get iconUrl;

  /// Serializes this channel for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(EpgChannel.serializer, this)! as Map<String, Object?>;
}

/// A room's guide id, as the IPTV site and the library both name it.
extension EpgChannelKeyX on EpgChannel {
  /// The storage key of this channel.
  String get key => epgChannelKey(sourceId, channelId);

  /// The name to show for this channel.
  String get primaryName => displayName.isEmpty ? channelId : displayName;
}
