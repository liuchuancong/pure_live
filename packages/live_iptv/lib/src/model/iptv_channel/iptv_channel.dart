// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/iptv_entry/iptv_entry.dart';
import 'package:live_iptv/src/model/serializers.dart';

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
abstract class IptvChannel implements Built<IptvChannel, IptvChannelBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory IptvChannel([void Function(IptvChannelBuilder)? updates]) = _$IptvChannel;

  /// A library channel record.
  factory IptvChannel.of({
    required String id,
    required IptvEntry entry,
    bool favorite = false,
    bool hidden = false,
    bool pinned = false,
    int position = 0,
    int? number,
  }) => IptvChannel(
    (b) => b
      ..id = id
      ..entry.replace(entry)
      ..favorite = favorite
      ..hidden = hidden
      ..pinned = pinned
      ..position = position
      ..number = number,
  );

  IptvChannel._();

  /// Restores a channel from JSON.
  factory IptvChannel.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(IptvChannel.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(IptvChannelBuilder b) => b
    ..favorite = false
    ..hidden = false
    ..pinned = false
    ..position = 0;

  /// The serializer built_value registers in [serializers].
  static Serializer<IptvChannel> get serializer => _$iptvChannelSerializer;

  /// The stable id that survives re-imports.
  String get id;

  /// The parsed entry the channel was built from.
  IptvEntry get entry;

  /// Whether the user favourited the channel.
  bool get favorite;

  /// Whether the user hid the channel from the lists.
  bool get hidden;

  /// Whether the channel sits in front of the list whatever its
  /// number or group says.
  bool get pinned;

  /// The user's own order among the library's channels.
  int get position;

  /// The remote-control number, when the user gave the channel one.
  int? get number;

  /// Serializes this channel for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(IptvChannel.serializer, this)! as Map<String, Object?>;
}
