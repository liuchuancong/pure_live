// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
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
///
/// [sources] names the playlists that list the channel. Channels are shared
/// between playlists by URL, so one channel can be claimed by several; a
/// playlist that stops listing it gives up its claim, and a channel nobody
/// claims any more leaves the library with the last playlist that had it.
/// An empty set is a channel stored before claims were recorded: nothing is
/// known about its owner, so nothing removes it on a guess.
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
    Iterable<String> sources = const <String>[],
  }) => IptvChannel(
    (b) => b
      ..id = id
      ..entry.replace(entry)
      ..favorite = favorite
      ..hidden = hidden
      ..pinned = pinned
      ..position = position
      ..number = number
      ..sources.replace(sources),
  );

  IptvChannel._();

  /// Restores a channel from JSON.
  factory IptvChannel.fromJson(Map<String, Object?> json) => serializers.deserializeWith(IptvChannel.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(IptvChannelBuilder b) => b
    ..favorite = false
    ..hidden = false
    ..pinned = false
    ..position = 0
    ..sources.replace(const <String>[]);

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

  /// The ids of the playlists that list this channel; empty for a channel
  /// stored before claims were recorded.
  BuiltSet<String> get sources;

  /// Every address of the channel: the primary first, then the fallbacks.
  Iterable<String> get urls sync* {
    yield entry.url;
    yield* entry.alternatives;
  }

  /// Serializes this channel for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(IptvChannel.serializer, this)! as Map<String, Object?>;
}
