// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';

part 'live_audience_update.g.dart';

/// One realtime audience figure delivered through the danmaku stream.
///
/// Typed so a platform's heat value can never be silently relabelled as a
/// concurrent head count (MODELS.md §5).
abstract class LiveAudienceUpdate implements Built<LiveAudienceUpdate, LiveAudienceUpdateBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveAudienceUpdate([void Function(LiveAudienceUpdateBuilder)? updates]) = _$LiveAudienceUpdate;

  /// Creates a LiveAudienceUpdate with already-normalized fields.
  /// Creates a LiveAudienceUpdate with already-normalized fields.
  factory LiveAudienceUpdate.of({required LiveAudienceSignalKind kind, required int value}) => LiveAudienceUpdate(
    (b) => b
      ..kind = kind
      ..value = value,
  );

  LiveAudienceUpdate._();

  /// What the figure counts.
  LiveAudienceSignalKind get kind;

  /// The figure itself.
  int get value;
}
