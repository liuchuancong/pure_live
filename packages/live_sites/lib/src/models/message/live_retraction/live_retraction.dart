// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_retraction.g.dart';

/// Which earlier messages a `LiveMessageType.retraction` takes back.
///
/// Exactly one targeting mode is set: a specific user (by id or, when the
/// platform only names them, by display name), a specific message, or the
/// whole chat.
abstract class LiveRetraction implements Built<LiveRetraction, LiveRetractionBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveRetraction([void Function(LiveRetractionBuilder)? updates]) = _$LiveRetraction;

  /// Creates a LiveRetraction with already-normalized fields.
  factory LiveRetraction.of({String? userId, String? messageId, bool all = false}) => LiveRetraction(
    (b) => b
      ..userId = userId
      ..messageId = messageId
      ..all = all,
  );

  LiveRetraction._();

  /// Deserializes a stored JSON record.
  factory LiveRetraction.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(LiveRetraction.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveRetraction> get serializer => _$liveRetractionSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveRetractionBuilder b) => b..all = false;

  /// The user whose messages are taken back, when targeted that way.
  String? get userId;

  /// The message taken back, when targeted that way.
  String? get messageId;

  /// The whole chat is taken back.
  bool get all;

  /// Whether this retraction targets the message shown for the given sender
  /// or id.
  bool matches({String? userId, String? userName, String? messageId}) {
    if (all) return true;
    final target = this.userId?.trim().toLowerCase();
    if (target != null && target.isNotEmpty) {
      if (userId != null && userId.trim().toLowerCase() == target) return true;
      if (userName != null && userName.trim().toLowerCase() == target) return true;
    }
    final id = this.messageId;
    return id != null && messageId != null && messageId == id;
  }
}
