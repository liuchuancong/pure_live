import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import './models/danmaku_content_item.dart';
import './models/danmaku_item.dart';

class SpecialDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> specialDanmakuItems;
  final double fontSize;
  final int fontWeight;
  final bool running;
  final int tick;
  final int batchThreshold;

  SpecialDanmakuPainter(
    this.progress,
    this.specialDanmakuItems,
    this.fontSize,
    this.fontWeight,
    this.running,
    this.tick, {
    this.batchThreshold = 10, // 默认值为10，可以自行调整
  });

  @override
  void paint(Canvas canvas, Size size) {
    var pictureCanvas = canvas;
    var batch = specialDanmakuItems.length > batchThreshold;
    late ui.PictureRecorder pictureRecorder;
    if (batch) {
      pictureRecorder = ui.PictureRecorder();
      pictureCanvas = Canvas(pictureRecorder);
    }
    for (final item in specialDanmakuItems) {
      final elapsed = tick - item.creationTime;
      final content = item.content as SpecialDanmakuContentItem;
      if (elapsed >= 0 && elapsed < content.duration) {
        _paintSpecialDanmaku(pictureCanvas, content, size, elapsed);
      }
    }
    if (batch) {
      canvas.drawPicture(pictureRecorder.endRecording());
    }
  }

  void _paintSpecialDanmaku(Canvas canvas, SpecialDanmakuContentItem item, Size size, int elapsed) {
    // 透明度动画
    late final alpha = item.alphaTween?.transform(elapsed / item.duration) ?? item.color.a;
    final color = item.alphaTween == null ? item.color : item.color..withAlpha((255.0 * (alpha)).round());
    // 文本
    if (color != item.painterCache?.text?.style?.color) {
      item.painterCache!.text = TextSpan(
        text: item.text,
        style: TextStyle(
          color: color,
          fontSize: item.fontSize,
          fontWeight: FontWeight.values[fontWeight],
          shadows: item.hasStroke ? [Shadow(color: Colors.black..withAlpha((255.0 * (alpha)).round()), blurRadius: 2)] : null,
        ),
      );
      item.painterCache!.layout();
    }

    // 路径动画 TODO

    // else 位移动画
    late double dx, dy;
    if (elapsed > item.translationStartDelay) {
      late double translateProgress = item.easingType.transform(min(1.0, (elapsed - item.translationStartDelay) / item.translationDuration));

      double getOffset(Tween<double> tween) => tween is ConstantTween ? tween.begin! : tween.transform(translateProgress);

      dx = getOffset(item.translateXTween) * size.width;
      dy = getOffset(item.translateYTween) * size.height;
    } else {
      dx = item.translateXTween.begin! * size.width;
      dy = item.translateYTween.begin! * size.height;
    }

    if (item.matrix != null) {
      canvas.save();
      canvas.translate(dx, dy);
      canvas.transform(item.matrix!.storage);
      item.painterCache!.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      item.painterCache!.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant SpecialDanmakuPainter oldDelegate) {
    return true;
  }
}
