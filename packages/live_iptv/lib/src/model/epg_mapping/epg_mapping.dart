// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'epg_mapping.g.dart';

/// The [EpgMapping.origin] this package writes when the matcher made the
/// mapping itself.
///
/// A top-level constant rather than a static on the class: the defaults the
/// builder hook and the named factory spell reference it, and keeping it
/// top-level leaves the model's surface unchanged for its callers.
const String epgAutoMappingOrigin = 'auto';

/// One channel-to-guide mapping.
///
/// [origin] records who made the mapping: an automatic one may be rewritten
/// by a later import, a hand-made one may not, and a locked one is final
/// even when the guide channel it names disappears — which is what stops a
/// user's deliberate choice from being undone by the next sync.
abstract class EpgMapping implements Built<EpgMapping, EpgMappingBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory EpgMapping([void Function(EpgMappingBuilder)? updates]) = _$EpgMapping;

  /// A mapping.
  factory EpgMapping.of({
    required String channelId,
    required String epgChannelKey,
    String playlistId = '',
    String epgSourceId = '',
    bool locked = false,
    String origin = epgAutoMappingOrigin,
  }) => EpgMapping(
    (b) => b
      ..channelId = channelId
      ..epgChannelKey = epgChannelKey
      ..playlistId = playlistId
      ..epgSourceId = epgSourceId
      ..locked = locked
      ..origin = origin,
  );

  EpgMapping._();

  /// Restores a mapping from JSON.
  factory EpgMapping.fromJson(Map<String, Object?> json) => serializers.deserializeWith(EpgMapping.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(EpgMappingBuilder b) => b
    ..playlistId = ''
    ..epgSourceId = ''
    ..locked = false
    ..origin = epgAutoMappingOrigin;

  /// The serializer built_value registers in [serializers].
  static Serializer<EpgMapping> get serializer => _$epgMappingSerializer;

  /// The playlist channel it belongs to.
  String get channelId;

  /// The guide channel's storage key, as `epgChannelKey` writes it.
  String get epgChannelKey;

  /// The playlist it came from.
  String get playlistId;

  /// The guide source the key belongs to.
  String get epgSourceId;

  /// Whether the user pinned it.
  bool get locked;

  /// Who created it: [epgAutoMappingOrigin] for the matcher, anything else
  /// for a human.
  String get origin;

  /// Serializes this mapping for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(EpgMapping.serializer, this)! as Map<String, Object?>;
}
