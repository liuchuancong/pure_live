// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_emote.g.dart';

/// One picture emote a platform names for a code inside a message text.
abstract class LiveEmote implements Built<LiveEmote, LiveEmoteBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveEmote([void Function(LiveEmoteBuilder)? updates]) = _$LiveEmote;

  /// Creates a LiveEmote with already-normalized fields.
  factory LiveEmote.of({required String code, required String url}) => LiveEmote(
    (b) => b
      ..code = code
      ..url = url,
  );

  LiveEmote._();

  /// Deserializes a stored JSON record.
  factory LiveEmote.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveEmote.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveEmote> get serializer => _$liveEmoteSerializer;

  /// The code the platform writes inside the text.
  String get code;

  /// Where the emote's picture lives.
  String get url;
}
