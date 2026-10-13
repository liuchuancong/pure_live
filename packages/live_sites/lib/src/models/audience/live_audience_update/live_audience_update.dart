import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_audience_update.freezed.dart';

/// One realtime audience figure delivered through the danmaku stream.
///
/// Typed so a platform's heat value can never be silently relabelled as a
/// concurrent head count (MODELS.md §5).
@freezed
abstract class LiveAudienceUpdate with _$LiveAudienceUpdate {
  /// Creates a LiveAudienceUpdate with already-normalized fields.
  const factory LiveAudienceUpdate({required LiveAudienceSignalKind kind, required int value}) = _LiveAudienceUpdate;
}
