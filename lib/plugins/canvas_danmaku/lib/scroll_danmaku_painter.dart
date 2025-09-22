import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'models/danmaku_item.dart';
import './utils/utils.dart';

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
  final int batchThreshold;

  final double totalDuration;
  final Paint selfSendPaint = Paint()
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
    this.tick, {
    this.batchThreshold = 10, // 默认值为10，可以自行调整
  }) : totalDuration = danmakuDurationInSeconds * 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final startPosition = size.width;

    if (scrollDanmakuItems.length > batchThreshold) {
      // 弹幕数量超过阈值时使用批量绘制
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas pictureCanvas = Canvas(pictureRecorder);

      for (var item in scrollDanmakuItems) {
        item.lastDrawTick ??= item.creationTime;
        final endPosition = -item.width;
        final distance = startPosition - endPosition;
        item.xPosition = item.xPosition +
            (((item.lastDrawTick! - tick) / totalDuration) * distance);

        if (item.xPosition < -item.width || item.xPosition > size.width) {
          continue;
        }

        item.paragraph ??= Utils.generateParagraph(
            item.content, size.width, fontSize, fontWeight);

        if (showStroke) {
          item.strokeParagraph ??= Utils.generateStrokeParagraph(
              item.content, size.width, fontSize, fontWeight);
          pictureCanvas.drawParagraph(
              item.strokeParagraph!, Offset(item.xPosition, item.yPosition));
        }

        if (item.content.selfSend) {
          pictureCanvas.drawRect(
              Offset(item.xPosition, item.yPosition).translate(-2, 2) &
                  (Size(item.width, item.height) + const Offset(4, 0)),
              selfSendPaint);
        }

        pictureCanvas.drawParagraph(
            item.paragraph!, Offset(item.xPosition, item.yPosition));
        item.lastDrawTick = tick;
      }

      final ui.Picture picture = pictureRecorder.endRecording();
      canvas.drawPicture(picture);
    } else {
      // 弹幕数量较少时直接绘制 (节约创建 canvas 的开销)
      for (var item in scrollDanmakuItems) {
        item.lastDrawTick ??= item.creationTime;
        final endPosition = -item.width;
        final distance = startPosition - endPosition;
        item.xPosition = item.xPosition +
            (((item.lastDrawTick! - tick) / totalDuration) * distance);

        if (item.xPosition < -item.width || item.xPosition > size.width) {
          continue;
        }

        item.paragraph ??= Utils.generateParagraph(
            item.content, size.width, fontSize, fontWeight);

        if (showStroke) {
          item.strokeParagraph ??= Utils.generateStrokeParagraph(
              item.content, size.width, fontSize, fontWeight);
          canvas.drawParagraph(
              item.strokeParagraph!, Offset(item.xPosition, item.yPosition));
        }

        if (item.content.selfSend) {
          canvas.drawRect(
              Offset(item.xPosition, item.yPosition).translate(-2, 2) &
                  (Size(item.width, item.height) + const Offset(4, 0)),
              selfSendPaint);
        }

        canvas.drawParagraph(
            item.paragraph!, Offset(item.xPosition, item.yPosition));
        item.lastDrawTick = tick;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
