// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_anchor_role.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'message_sender.g.dart';

/// Who sent a danmaku message: identity, badges, and standing.
///
/// [fanBadgeLevel]/[fanBadgeName] are the fan-medal pair (`''` = not worn);
/// [membershipTier] is the paid tier (bilibili 3=Governor/2=Admiral/1=Captain,
/// douyu/huya nobility), null = none; [role] says whether the sender is the
/// streamer, staff, or a viewer.
abstract class MessageSender implements Built<MessageSender, MessageSenderBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory MessageSender([void Function(MessageSenderBuilder)? updates]) = _$MessageSender;

  /// The normalized-fields constructor; construct through
  /// [MessageSender.normalized] unless the caller normalized upstream.
  factory MessageSender.of({
    String userId = '',
    String userName = '',
    String? avatarUrl,
    String? userLevel,
    String fanBadgeLevel = '',
    String fanBadgeName = '',
    LiveMessageColor? nameColor,
    List<LiveBadge> badges = const [],
    LiveAnchorRole role = LiveAnchorRole.viewer,
    int? membershipTier,
  }) => MessageSender(
    (b) => b
      ..userId = userId
      ..userName = userName
      ..avatarUrl = avatarUrl
      ..userLevel = userLevel
      ..fanBadgeLevel = fanBadgeLevel
      ..fanBadgeName = fanBadgeName
      ..nameColor = nameColor
      ..badges.replace(badges)
      ..role = role
      ..membershipTier = membershipTier,
  );

  MessageSender._();

  /// Deserializes a stored JSON record.
  factory MessageSender.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(MessageSender.serializer, json)!;

  /// Adapter entry point: normalizes names and ids once and delegates.
  factory MessageSender.normalized({
    String userId = '',
    String userName = '',
    String? avatarUrl,
    String? userLevel,
    String fanBadgeLevel = '',
    String fanBadgeName = '',
    LiveMessageColor? nameColor,
    List<LiveBadge> badges = const [],
    LiveAnchorRole role = LiveAnchorRole.viewer,
    int? membershipTier,
  }) => MessageSender.of(
    userId: userId.trim(),
    userName: userName.trim(),
    avatarUrl: avatarUrl?.trim(),
    userLevel: userLevel?.trim(),
    fanBadgeLevel: fanBadgeLevel.trim(),
    fanBadgeName: fanBadgeName.trim(),
    nameColor: nameColor,
    badges: badges,
    role: role,
    membershipTier: membershipTier,
  );

  /// The serializer built_value registers in [serializers].
  static Serializer<MessageSender> get serializer => _$messageSenderSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(MessageSenderBuilder b) => b
    ..userId = ''
    ..userName = ''
    ..fanBadgeLevel = ''
    ..fanBadgeName = ''
    ..role = LiveAnchorRole.viewer;

  /// The sender's platform uid.
  String get userId;

  /// The sender's display name.
  String get userName;

  /// The sender's avatar.
  String? get avatarUrl;

  /// The sender's platform level, when it says so.
  String? get userLevel;

  /// The fan-medal level, `''` when not worn.
  String get fanBadgeLevel;

  /// The fan-medal name, `''` when not worn.
  String get fanBadgeName;

  /// The color the platform gives the name.
  LiveMessageColor? get nameColor;

  /// The badges worn next to the name.
  BuiltList<LiveBadge> get badges;

  /// Whether the sender is the streamer, staff, or a viewer.
  LiveAnchorRole get role;

  /// The paid membership tier, null = none.
  int? get membershipTier;
}
