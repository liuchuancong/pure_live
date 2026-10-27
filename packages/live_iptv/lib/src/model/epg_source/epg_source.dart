// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'epg_source.g.dart';

/// One guide source: a guide file the user imported, or a URL a sync can ask
/// again.
///
/// The fields keep the previous generation's names, so a source stored by it
/// reads back unchanged; [source] is the URL of a remote guide or the path of
/// an imported file, which is what [EpgSourceX.isRemote] tells apart.
abstract class EpgSource implements Built<EpgSource, EpgSourceBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory EpgSource([void Function(EpgSourceBuilder)? updates]) = _$EpgSource;

  /// A guide source.
  factory EpgSource.of({
    required String id,
    required String name,
    required String source,
    DateTime? lastRefresh,
    DateTime? createdAt,
    bool autoUpdate = true,
  }) => EpgSource(
    (b) => b
      ..id = id
      ..name = name
      ..source = source
      ..lastRefresh = lastRefresh
      ..createdAt = createdAt
      ..autoUpdate = autoUpdate,
  );

  EpgSource._();

  /// Restores a source from JSON.
  factory EpgSource.fromJson(Map<String, Object?> json) => serializers.deserializeWith(EpgSource.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(EpgSourceBuilder b) => b..autoUpdate = true;

  /// The serializer built_value registers in [serializers].
  static Serializer<EpgSource> get serializer => _$epgSourceSerializer;

  /// The source's id.
  String get id;

  /// The name shown in the interface.
  String get name;

  /// An http(s) URL, or the path of an imported file.
  String get source;

  /// When it was last imported or synced successfully.
  DateTime? get lastRefresh;

  /// When it was first imported.
  DateTime? get createdAt;

  /// Whether a sync may refresh it by itself.
  bool get autoUpdate;

  /// Serializes this source for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(EpgSource.serializer, this)! as Map<String, Object?>;
}

/// Whether [source] is a network URL rather than a file path.
extension EpgSourceX on EpgSource {
  /// Whether this source can be synced over the network.
  bool get isRemote => source.startsWith('http://') || source.startsWith('https://');
}
