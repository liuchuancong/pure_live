import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_gift.freezed.dart';
part 'live_gift.g.dart';

/// Gift pricing units, normalized from the platforms' coin systems.
enum LiveGiftUnit {
  /// Platform silver coins (free-tier currency).
  silver,

  /// Platform gold coins (paid currency).
  gold,

  /// Direct RMB amounts.
  rmb,
}

/// A gift event payload attached to a `LiveMessage` of the gift kind.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveGift with _$LiveGift {
  /// A gift event: [count] gifts of [name], combo-merged when the
  /// platform streams combos.
  const factory LiveGift({
    required String name,
    required int count,
    @Default(LiveGiftUnit.gold) LiveGiftUnit unit,
    @Default(0) int unitPrice,
    int? totalValue,
    String? combo,
  }) = _LiveGift;

  /// Restores a gift from JSON.
  factory LiveGift.fromJson(Map<String, Object?> json) => _$LiveGiftFromJson(json);
}

/// A paid-highlight payload attached to a `LiveMessage` of the super-chat
/// kind.
///
/// A super chat is a donation shown apart: [price] with [unit] is what was
/// paid, [priceText] what the platform writes for it, and [startTime]/
/// [endTime] the window the client keeps it highlighted — platforms give no
/// duration, so it is the client's own table, per amount tier.
@freezed
abstract class LiveSuperChat with _$LiveSuperChat {
  /// A super chat.
  const factory LiveSuperChat({
    /// The donor's message (or the video or mission the donation names).
    @Default('') String message,

    /// What was paid, in [unit].
    @Default(0) int price,

    /// The text the platform writes for [price] (`1,000 치즈`).
    @Default('') String priceText,

    /// The unit [price] counts in.
    @Default(LiveGiftUnit.gold) LiveGiftUnit unit,

    /// When the highlight starts.
    DateTime? startTime,

    /// When the highlight ends (the client's own duration per tier).
    DateTime? endTime,
  }) = _LiveSuperChat;

  /// Restores a super chat from JSON.
  factory LiveSuperChat.fromJson(Map<String, Object?> json) => _$LiveSuperChatFromJson(json);
}

/// The computed total value of a gift in its unit.
extension LiveGiftValue on LiveGift {
  /// The total value in units, computed or reported.
  int get value => totalValue ?? unitPrice * count;
}

/// An audience update payload.
@freezed
abstract class LiveAudienceUpdate with _$LiveAudienceUpdate {
  /// An update carrying [watching] and/or [onlineViewers].
  const factory LiveAudienceUpdate({int? watching, int? onlineViewers}) = _LiveAudienceUpdate;

  /// Restores an update from JSON.
  factory LiveAudienceUpdate.fromJson(Map<String, Object?> json) => _$LiveAudienceUpdateFromJson(json);
}
