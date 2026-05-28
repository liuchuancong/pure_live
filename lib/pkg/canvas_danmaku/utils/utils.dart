import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class Utils {
  // 计算混合内容的总宽度
  static double calculateMixedContentWidth(DanmakuContentItem content, double fontSize) {
    double totalWidth = 0;
    final emojiSize = fontSize * 1.2;
    for (final item in content.mixedContent) {
      if (item.type == ContentType.text) {
        // 计算文本宽度
        final textSpan = TextSpan(
          text: item.value,
          style: TextStyle(fontSize: fontSize),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        totalWidth += textPainter.width;
      } else {
        totalWidth += emojiSize;
      }
    }
    return totalWidth;
  }

  static void drawMixedContent(
    Canvas canvas,
    DanmakuContentItem content,
    Offset offset,
    double fontSize,
    int fontWeight,
    bool showStroke,
    bool selfSend,
    Paint? selfSendPaint,
  ) {
    double currentX = offset.dx;
    final currentY = offset.dy;
    final emojiSize = fontSize * 1.2;

    // 绘制自发送弹幕的边框（如果需要）
    if (selfSend && selfSendPaint != null) {
      final totalWidth = calculateMixedContentWidth(content, fontSize);
      canvas.drawRect(Rect.fromLTWH(currentX, currentY, totalWidth, fontSize), selfSendPaint);
    }

    // 绘制实际内容（文本和表情）
    for (final item in content.mixedContent) {
      if (item.type == ContentType.text) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: item.value,
            style: TextStyle(
              color: content.color,
              fontSize: fontSize,
              fontWeight: FontWeight.values[fontWeight],
              fontFamily: content.fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final strokePainter = TextPainter(
          text: TextSpan(
            text: item.value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.values[fontWeight],
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8
                ..color = Colors.black54, // 这里已经通过foreground设置了颜色
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        strokePainter.paint(canvas, Offset(currentX, currentY));
        textPainter.paint(canvas, Offset(currentX, currentY));
        currentX += textPainter.width;
      } else {
        final image = EmojiManager.getEmoji(item.value);
        if (image != null) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            Rect.fromLTWH(currentX, currentY, emojiSize, emojiSize),
            Paint()..filterQuality = FilterQuality.high,
          );
        } else {
          final textPainter = TextPainter(
            text: TextSpan(
              text: item.value,
              style: TextStyle(color: content.color, fontSize: fontSize, fontFamily: content.fontFamily),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(canvas, Offset(currentX, currentY));
        }
        currentX += emojiSize;
      }
    }
  }

  static ui.Paragraph generateParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: fontSize,
              fontWeight: FontWeight.values[fontWeight],
              textDirection: TextDirection.ltr,
            ),
          )
          ..pushStyle(ui.TextStyle(color: content.color))
          ..addText(content.text);
    return builder.build()..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static ui.Paragraph generateStrokeParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final ui.ParagraphBuilder strokeBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: fontSize,
              fontFamily: content.fontFamily,
              fontWeight: FontWeight.values[fontWeight],
              textDirection: TextDirection.ltr,
            ),
          )
          ..pushStyle(ui.TextStyle(foreground: strokePaint))
          ..addText(content.text);

    return strokeBuilder.build()..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }
}
