import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_gift.freezed.dart';
part 'live_gift.g.dart';

/// One gift event.
///
/// [count] is how many were sent in this hit; the run's accumulated total
/// lives in [combo]. [recipientName] names the receiving streamer of a
/// cross-room gift (a PK partner); `''` means the current streamer.
@freezed
abstract class LiveGift with _$LiveGift {
  /// Creates a LiveGift with already-normalized fields.
  const factory LiveGift({
    @Default('') String giftId,
    @Default('') String name,
    String? iconUrl,
    @Default(LiveGiftKind.normal) LiveGiftKind kind,
    @Default(1) int count,
    @Default(LiveGiftValue()) LiveGiftValue value,
    @Default(LiveGiftCombo()) LiveGiftCombo combo,
    @Default('') String recipientName,
  }) = _LiveGift;

  /// Deserializes a stored JSON record.
  factory LiveGift.fromJson(Map<String, Object?> json) => _$LiveGiftFromJson(json);
}
