import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_anchor_role.dart';
import 'package:live_sites/src/models/message/live_badge/live_badge.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'message_sender.freezed.dart';
part 'message_sender.g.dart';

/// Who sent a danmaku message: identity, badges, and standing.
///
/// [fanBadgeLevel]/[fanBadgeName] are the fan-medal pair (`''` = not worn);
/// [membershipTier] is the paid tier (bilibili 3=Governor/2=Admiral/1=Captain,
/// douyu/huya nobility), null = none; [role] says whether the sender is the
/// streamer, staff, or a viewer.
@freezed
abstract class MessageSender with _$MessageSender {
  /// The normalized-fields constructor (code generation and copyWith
  /// target); construct through [MessageSender.normalized] unless the caller
  /// normalized upstream.
  const factory MessageSender({
    @Default('') String userId,
    @Default('') String userName,
    String? avatarUrl,
    String? userLevel,
    @Default('') String fanBadgeLevel,
    @Default('') String fanBadgeName,
    LiveMessageColor? nameColor,
    @Default([]) List<LiveBadge> badges,
    @Default(LiveAnchorRole.viewer) LiveAnchorRole role,
    int? membershipTier,
  }) = _MessageSender;

  /// Deserializes a stored JSON record.
  factory MessageSender.fromJson(Map<String, Object?> json) => _$MessageSenderFromJson(json);

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
  }) => MessageSender(
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
}
