import 'dart:ui';
import 'package:flame_barrage/flame_barrage.dart';

class BarrageItem {
  const BarrageItem({
    required this.content,
    this.type = BarrageType.scroll,
    this.userId,
    this.userName,
    this.priority = 0,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.letterSpacing,
    this.opacity,
    this.showStroke,
    this.strokeColor,
    this.strokeWidth,
    this.showShadow,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffset,
    this.fixedDuration,
    this.emojiSize,
    this.baseSpeed,
    this.overlapSafeGap,
    this.cachedFragments,
    this.cachedLayout,
    this.cachedPicture,
    this.onTapDown,
    this.onLongTapDown,
    this.onTapUp,
    this.onTapCancel,
  });

  final String content;
  final BarrageType type;
  final String? userId;
  final String? userName;
  final int priority;

  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final String? fontFamily;
  final double? letterSpacing;
  final double? opacity;
  final bool? showStroke;
  final Color? strokeColor;
  final double? strokeWidth;
  final bool? showShadow;
  final Color? shadowColor;
  final double? shadowBlur;
  final Offset? shadowOffset;
  final Duration? fixedDuration;
  final double? emojiSize;
  final double? baseSpeed;
  final double? overlapSafeGap;

  final List<Fragment>? cachedFragments;
  final LayoutResult? cachedLayout;
  final Picture? cachedPicture;
  final void Function()? onTapDown;
  final void Function()? onLongTapDown;
  final void Function()? onTapUp;
  final void Function()? onTapCancel;
}
