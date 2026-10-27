// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_iptv/src/model/serializers.dart';

part 'iptv_entry.g.dart';

/// One channel entry as parsed from a playlist.
///
/// Headers carry the `#EXTVLCOPT`/`#KODIPROP`/`url|k=v` requests the
/// playlist declared; the catchup fields drive time-shift URL building
/// later.
///
/// [channelNumber] is the number the *provider* wrote (`tvg-chno`): a hint,
/// not the user's own — the library turns it into `IptvChannel.number`, which
/// is what a remote control types, and which survives the next playlist
/// coming back without the attribute.
abstract class IptvEntry implements Built<IptvEntry, IptvEntryBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory IptvEntry([void Function(IptvEntryBuilder)? updates]) = _$IptvEntry;

  /// A parsed channel entry.
  factory IptvEntry.of({
    required String name,
    required String url,
    String? group,
    String? tvgId,
    String? tvgLogo,
    int? channelNumber,
    Map<String, String> headers = const <String, String>{},
    List<String> alternatives = const <String>[],
    String? catchupSource,
    String? catchupMode,
    String? catchupDays,
  }) => IptvEntry(
    (b) => b
      ..name = name
      ..url = url
      ..group = group
      ..tvgId = tvgId
      ..tvgLogo = tvgLogo
      ..channelNumber = channelNumber
      ..headers.replace(headers)
      ..alternatives.replace(alternatives)
      ..catchupSource = catchupSource
      ..catchupMode = catchupMode
      ..catchupDays = catchupDays,
  );

  IptvEntry._();

  /// Restores an entry from JSON.
  factory IptvEntry.fromJson(Map<String, Object?> json) => serializers.deserializeWith(IptvEntry.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(IptvEntryBuilder b) => b
    ..headers.replace(const <String, String>{})
    ..alternatives.replace(const <String>[]);

  /// The serializer built_value registers in [serializers].
  static Serializer<IptvEntry> get serializer => _$iptvEntrySerializer;

  /// The channel's display name.
  String get name;

  /// The stream address.
  String get url;

  /// The group title the playlist wrote, when it wrote one.
  String? get group;

  /// The guide id the playlist declared (`tvg-id`).
  String? get tvgId;

  /// The logo the playlist declared (`tvg-logo`).
  String? get tvgLogo;

  /// The number the *provider* wrote (`tvg-chno`): a hint, not the user's own.
  int? get channelNumber;

  /// The `#EXTVLCOPT`/`#KODIPROP`/`url|k=v` requests the playlist declared.
  BuiltMap<String, String> get headers;

  /// Fallback addresses tried when [url] fails.
  BuiltList<String> get alternatives;

  /// The time-shift base address the playlist declared.
  String? get catchupSource;

  /// How a time-shift URL is built from [catchupSource].
  String? get catchupMode;

  /// How many days of replay the source keeps.
  String? get catchupDays;

  /// Serializes this entry for the store.
  Map<String, Object?> toJson() => serializers.serializeWith(IptvEntry.serializer, this)! as Map<String, Object?>;
}
