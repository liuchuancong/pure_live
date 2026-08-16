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
    this.fontFamily,
    this.showStroke,
    this.strokeColor,
    this.strokeWidth,
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
  final String? fontFamily;
  final bool? showStroke;
  final Color? strokeColor;
  final double? strokeWidth;
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
