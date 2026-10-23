// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_super_chat_display.g.dart';

/// The presentation colors a platform prescribes for one super chat
/// (bilibili's red-gold banner family), as `#RRGGBB` strings.
abstract class SuperChatDisplay implements Built<SuperChatDisplay, SuperChatDisplayBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory SuperChatDisplay([void Function(SuperChatDisplayBuilder)? updates]) = _$SuperChatDisplay;

  /// Creates a SuperChatDisplay with already-normalized fields.
  factory SuperChatDisplay.of({String backgroundColor = '', String backgroundBottomColor = ''}) => SuperChatDisplay(
    (b) => b
      ..backgroundColor = backgroundColor
      ..backgroundBottomColor = backgroundBottomColor,
  );

  SuperChatDisplay._();

  /// Deserializes a stored JSON record.
  factory SuperChatDisplay.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(SuperChatDisplay.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<SuperChatDisplay> get serializer => _$superChatDisplaySerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SuperChatDisplayBuilder b) => b
    ..backgroundColor = ''
    ..backgroundBottomColor = '';

  /// The banner's main color.
  String get backgroundColor;

  /// The banner's gradient tail color.
  String get backgroundBottomColor;
}
