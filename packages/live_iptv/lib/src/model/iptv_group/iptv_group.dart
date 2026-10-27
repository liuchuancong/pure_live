// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'iptv_group.g.dart';

/// A channel group as the user ordered it.
///
/// The name is the key — it is what the playlist's `group-title` writes,
/// and a playlist is rewritten constantly while a library is kept. So a
/// group with no record here is not an error: it simply sorts after the
/// ones the user arranged, in the order its channels appear. [hidden]
/// takes the whole group out of the lists without touching the channels in
/// it, because "I never watch the shopping channels" is a statement about
/// a group, and un-hiding it must give back exactly what was there.
abstract class IptvGroup implements Built<IptvGroup, IptvGroupBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory IptvGroup([void Function(IptvGroupBuilder)? updates]) = _$IptvGroup;

  /// A group record.
  factory IptvGroup.of({required String name, int order = 0, bool pinned = false, bool hidden = false}) =>
      IptvGroup(
        (b) => b
          ..name = name
          ..order = order
          ..pinned = pinned
          ..hidden = hidden,
      );

  IptvGroup._();

  /// Restores a group from JSON.
  factory IptvGroup.fromJson(Map<String, Object?> json) => serializers.deserializeWith(IptvGroup.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(IptvGroupBuilder b) => b
    ..order = 0
    ..pinned = false
    ..hidden = false;

  /// The serializer built_value registers in [serializers].
  static Serializer<IptvGroup> get serializer => _$iptvGroupSerializer;

  /// The group's name, as the playlist's `group-title` writes it.
  String get name;

  /// The user's own order among the groups.
  int get order;

  /// Whether the group sits in front of the list.
  bool get pinned;

  /// Whether the group is taken out of the lists.
  bool get hidden;

  /// Serializes this group for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(IptvGroup.serializer, this)! as Map<String, Object?>;
}
