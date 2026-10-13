import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_message_placement.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_message_style.freezed.dart';

/// Presentation of a locally composed danmaku message.
///
/// Platform messages keep the room-wide danmaku configuration; only
/// `isLocal` messages carry a style. Purely a UI-facing value object — it is
/// never persisted by this package.
@freezed
abstract class LiveMessageStyle with _$LiveMessageStyle {
  /// Creates a LiveMessageStyle with already-normalized fields.
  const factory LiveMessageStyle({
    required double fontSize,
    required double baseSpeed,
    required int fontWeight,
    required bool showStroke,
    required double strokeWidth,
    @Default(LiveMessagePlacement.scroll) LiveMessagePlacement placement,
    String? fontFamily,
    @Default(false) bool italic,
    @Default(1) double opacity,
    @Default(0) double letterSpacing,
    @Default(0xFF000000) int strokeColor,
    @Default(false) bool showShadow,
    @Default(0xFF000000) int shadowColor,
    @Default(2) double shadowBlur,
    @Default(1) double shadowOffset,
    @Default(4000) int fixedDurationMs,
  }) = _LiveMessageStyle;
}
