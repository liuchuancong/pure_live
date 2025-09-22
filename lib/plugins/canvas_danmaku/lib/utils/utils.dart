import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/danmaku_content_item.dart';

class Utils {
  static ui.Paragraph generateParagraph(DanmakuContentItem content, double danmakuWidth,
      double fontSize, int fontWeight) {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
    ))
      ..pushStyle(ui.TextStyle(
        color: content.color,
      ))
      ..addText(content.text);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static ui.Paragraph generateStrokeParagraph(DanmakuContentItem content,
      double danmakuWidth, double fontSize, int fontWeight) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final ui.ParagraphBuilder strokeBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
    ))
          ..pushStyle(ui.TextStyle(
            foreground: strokePaint,
          ))
          ..addText(content.text);

    return strokeBuilder.build()
      ..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }
}
