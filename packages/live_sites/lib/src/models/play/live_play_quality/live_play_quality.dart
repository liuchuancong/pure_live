// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';

part 'live_play_quality.g.dart';

/// One quality a room offers.
///
/// [qualityId] is what a line request sends back to the platform (bilibili
/// `qn`, douyu `rate`); [label] is only display text. [isPlaybackUnconfirmed]
/// marks a response where the server may have silently downgraded an
/// anonymous request (ARCHITECTURE.md §8).
abstract class LivePlayQuality implements Built<LivePlayQuality, LivePlayQualityBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePlayQuality([void Function(LivePlayQualityBuilder)? updates]) = _$LivePlayQuality;

  /// Creates a LivePlayQuality with already-normalized fields.
  factory LivePlayQuality.of({
    required String label,
    String? qualityId,
    int platformOrder = 0,
    bool isPlaybackUnconfirmed = false,
    LiveStreamCodec? codec,
  }) => LivePlayQuality(
    (b) => b
      ..label = label
      ..qualityId = qualityId
      ..platformOrder = platformOrder
      ..isPlaybackUnconfirmed = isPlaybackUnconfirmed
      ..codec = codec,
  );

  LivePlayQuality._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LivePlayQualityBuilder b) => b
    ..platformOrder = 0
    ..isPlaybackUnconfirmed = false;

  /// The quality's display text.
  String get label;

  /// What a line request sends back to the platform.
  String? get qualityId;

  /// The platform's own ordering.
  int get platformOrder;

  /// The server may have silently downgraded an anonymous request.
  bool get isPlaybackUnconfirmed;

  /// The declared codec, when the platform says so.
  LiveStreamCodec? get codec;
}
