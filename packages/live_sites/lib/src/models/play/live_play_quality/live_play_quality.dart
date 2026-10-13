import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_play_quality.freezed.dart';

/// One quality a room offers.
///
/// [qualityId] is what a line request sends back to the platform (bilibili
/// `qn`, douyu `rate`); [label] is only display text. [isPlaybackUnconfirmed]
/// marks a response where the server may have silently downgraded an
/// anonymous request (ARCHITECTURE.md §8).
@freezed
abstract class LivePlayQuality with _$LivePlayQuality {
  /// Creates a LivePlayQuality with already-normalized fields.
  const factory LivePlayQuality({
    required String label,
    String? qualityId,
    @Default(0) int platformOrder,
    @Default(false) bool isPlaybackUnconfirmed,
    LiveStreamCodec? codec,
  }) = _LivePlayQuality;
}
