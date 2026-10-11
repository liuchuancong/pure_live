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
