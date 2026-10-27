// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';

part 'guide_channel.g.dart';

/// A guide channel as a parser read it, before it is stored.
///
/// No JSON: a parsed guide channel is turned into an `EpgChannel` the moment
/// it is saved, so its three fields never cross the storage boundary as
/// themselves, and giving it a `toJson` would invite writing the wrong
/// record.
abstract class GuideChannel implements Built<GuideChannel, GuideChannelBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory GuideChannel([void Function(GuideChannelBuilder)? updates]) = _$GuideChannel;

  /// A parsed guide channel.
  factory GuideChannel.of({
    required String id,
    List<String> displayNames = const <String>[],
    String? iconUrl,
  }) => GuideChannel(
    (b) => b
      ..id = id
      ..displayNames.replace(displayNames)
      ..iconUrl = iconUrl,
  );

  GuideChannel._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(GuideChannelBuilder b) => b..displayNames.replace(const <String>[]);

  /// The guide's own channel id: `tvg-id` in a playlist matches it.
  String get id;

  /// Every `display-name` of the channel, in file order.
  BuiltList<String> get displayNames;

  /// The channel's icon, when the guide names one.
  String? get iconUrl;
}
