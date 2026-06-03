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
    final double startPosition = size.width;

    for (final item in scrollDanmakuItems) {
      final currentWidth = item.cachedWidth;
      if (currentWidth == null) continue;

      final int elapsedTime = tick - item.creationTime;
      final double timeProgress = elapsedTime / totalDuration;

      if (timeProgress >= 1.0 || timeProgress < 0) continue;

      final double endPosition = -currentWidth;
      final double currentX = startPosition + (endPosition - startPosition) * timeProgress;

      item.xPosition = currentX;

      if (currentX < -currentWidth || currentX > size.width) {
        continue;
      }

      Utils.drawMixedContent(
        canvas,
        item.content,
        Offset(currentX, item.yPosition),
        fontSize,
        fontWeight,
        showStroke,
        item.content.selfSend,
        _selfSendPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScrollDanmakuPainter oldDelegate) {
    if (showStroke != oldDelegate.showStroke ||
        fontSize != oldDelegate.fontSize ||
        fontWeight != oldDelegate.fontWeight) {
      Utils.clearCache();
      return true;
    }

    return tick != oldDelegate.tick ||
        scrollDanmakuItems.length != oldDelegate.scrollDanmakuItems.length ||
        progress != oldDelegate.progress ||
        fontSize != oldDelegate.fontSize ||
        fontWeight != oldDelegate.fontWeight ||
        showStroke != oldDelegate.showStroke ||
        running != oldDelegate.running;
  }
}
