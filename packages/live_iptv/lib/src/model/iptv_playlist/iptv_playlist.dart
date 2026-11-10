// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'iptv_playlist.g.dart';

/// A playlist source the user imported.
abstract class IptvPlaylist implements Built<IptvPlaylist, IptvPlaylistBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory IptvPlaylist([void Function(IptvPlaylistBuilder)? updates]) = _$IptvPlaylist;

  /// A playlist record; [url] is set for remote playlists, else the
  /// content lives next to the user's own files.
  factory IptvPlaylist.of({
    required String id,
    required String name,
    required DateTime importedAt,
    String? url,
    int channelCount = 0,
    List<String> guideUrls = const <String>[],
  }) => IptvPlaylist(
    (b) => b
      ..id = id
      ..name = name
      ..importedAt = importedAt
      ..url = url
      ..channelCount = channelCount
      ..guideUrls.replace(guideUrls),
  );

  IptvPlaylist._();

  /// Restores a playlist from JSON.
  factory IptvPlaylist.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(IptvPlaylist.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(IptvPlaylistBuilder b) => b
    ..channelCount = 0
    ..guideUrls.replace(const <String>[]);

  /// The serializer built_value registers in [serializers].
  static Serializer<IptvPlaylist> get serializer => _$iptvPlaylistSerializer;

  /// The playlist's stable id.
  String get id;

  /// The name shown in the interface.
  String get name;

  /// When the user imported (or last re-imported) the playlist.
  DateTime get importedAt;

  /// The remote address, when the playlist came from a URL.
  String? get url;

  /// How many channels the last import produced.
  int get channelCount;

  /// The guide addresses the playlist's own header declared (`x-tvg-url`,
  /// `url-tvg`), in the order it listed them: the first is the provider's
  /// choice, the rest its mirrors.
  BuiltList<String> get guideUrls;

  /// Serializes this playlist for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(IptvPlaylist.serializer, this)! as Map<String, Object?>;
}
