import 'models/danmaku_item.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/pkg/canvas_danmaku/utils/utils.dart';

class ScrollDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> scrollDanmakuItems;

  final int danmakuDurationInSeconds;

  final double fontSize;
  final int fontWeight;
  final bool showStroke;

  final double danmakuHeight;

  final bool running;
  final int tick;

  final double totalDuration;

  static final Paint _selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.green;

  ScrollDanmakuPainter(
    this.progress,
    this.scrollDanmakuItems,
    this.danmakuDurationInSeconds,
    this.fontSize,
    this.fontWeight,
    this.showStroke,
    this.danmakuHeight,
    this.running,
    this.tick,
  ) : totalDuration = danmakuDurationInSeconds * 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final startPosition = size.width;

    for (final item in scrollDanmakuItems) {
      item.lastDrawTick ??= item.creationTime;

      final currentWidth = item.cachedWidth;

      if (currentWidth == null) {
        continue;
      }

      final endPosition = -currentWidth;

      final distance = startPosition - endPosition;

      item.xPosition += ((item.lastDrawTick! - tick) / totalDuration) * distance;

      if (item.xPosition < -currentWidth || item.xPosition > size.width) {
        item.lastDrawTick = tick;
        continue;
      }

      Utils.drawMixedContent(
        canvas,
        item.content,
        Offset(item.xPosition, item.yPosition),
        fontSize,
        fontWeight,
        showStroke,
        item.content.selfSend,
        _selfSendPaint,
      );

      item.lastDrawTick = tick;
    }
  }

  @override
  bool shouldRepaint(covariant ScrollDanmakuPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        tick != oldDelegate.tick ||
        scrollDanmakuItems.length != oldDelegate.scrollDanmakuItems.length ||
        fontSize != oldDelegate.fontSize ||
        fontWeight != oldDelegate.fontWeight ||
        showStroke != oldDelegate.showStroke;
  }
}
