import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class Utils {
  static final Paint _emojiPaint = Paint()..filterQuality = FilterQuality.medium;
  static final Map<String, double> _widthCache = {};
  static final Map<String, TextPainter> _textPainterCache = {};
  static final Map<String, TextPainter> _strokePainterCache = {};

  static String _textKey(String text, double fontSize, int fontWeight, String? fontFamily, Color color) {
    return '$text|$fontSize|$fontWeight|${fontFamily ?? ""}|${color.toARGB32()}';
  }

  static String _strokeKey(String text, double fontSize, int fontWeight, String? fontFamily) {
    return '$text|$fontSize|$fontWeight|${fontFamily ?? ""}';
  }

  static double calculateMixedContentWidth(DanmakuContentItem content, double fontSize) {
    double totalWidth = 0;
    final emojiSize = fontSize * 1.2;

    for (final item in content.mixedContent) {
      if (item.type == ContentType.text) {
        final cacheKey = '${item.value}|$fontSize|${content.fontFamily ?? ""}';
        var width = _widthCache[cacheKey];
        if (width == null) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: item.value,
              style: TextStyle(fontSize: fontSize, fontFamily: content.fontFamily),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          width = textPainter.width;
          _widthCache[cacheKey] = width;
        }
        totalWidth += width;
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
    final double baseY = offset.dy;
    final emojiSize = fontSize * 1.2;
    final targetFontWeight = FontWeight.values[fontWeight];

    final testPainter = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(fontSize: fontSize, fontWeight: targetFontWeight, fontFamily: content.fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double textHeight = testPainter.height;
    final double emojiOffsetY = (textHeight - emojiSize) / 2.0;

    if (selfSend && selfSendPaint != null) {
      final totalWidth = calculateMixedContentWidth(content, fontSize);
      canvas.drawRect(Rect.fromLTWH(currentX, baseY, totalWidth, textHeight), selfSendPaint);
    }

    for (final item in content.mixedContent) {
      if (item.type == ContentType.text) {
        final textCacheKey = _textKey(item.value, fontSize, fontWeight, content.fontFamily, content.color);
        var textPainter = _textPainterCache[textCacheKey];

        if (textPainter == null) {
          textPainter = TextPainter(
            text: TextSpan(
              text: item.value,
              style: TextStyle(
                color: content.color,
                fontSize: fontSize,
                fontWeight: targetFontWeight,
                fontFamily: content.fontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          _textPainterCache[textCacheKey] = textPainter;
        }

        if (showStroke) {
          final strokeCacheKey = _strokeKey(item.value, fontSize, fontWeight, content.fontFamily);
          var strokePainter = _strokePainterCache[strokeCacheKey];

          if (strokePainter == null) {
            strokePainter = TextPainter(
              text: TextSpan(
                text: item.value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: targetFontWeight,
                  fontFamily: content.fontFamily,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5
                    ..color = Colors.black54,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            _strokePainterCache[strokeCacheKey] = strokePainter;
          }
          strokePainter.paint(canvas, Offset(currentX, baseY));
        }

        textPainter.paint(canvas, Offset(currentX, baseY));
        currentX += textPainter.width;
      } else {
        final image = EmojiManager.getEmoji(item.value);

        if (image != null) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            Rect.fromLTWH(currentX, baseY + emojiOffsetY, emojiSize, emojiSize),
            _emojiPaint,
          );
        } else {
          final textCacheKey = _textKey(item.value, fontSize, fontWeight, content.fontFamily, content.color);
          var textPainter = _textPainterCache[textCacheKey];

          if (textPainter == null) {
            textPainter = TextPainter(
              text: TextSpan(
                text: item.value,
                style: TextStyle(
                  color: content.color,
                  fontSize: fontSize,
                  fontWeight: targetFontWeight,
                  fontFamily: content.fontFamily,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            _textPainterCache[textCacheKey] = textPainter;
          }

          if (showStroke) {
            final strokeCacheKey = _strokeKey(item.value, fontSize, fontWeight, content.fontFamily);
            var strokePainter = _strokePainterCache[strokeCacheKey];

            if (strokePainter == null) {
              strokePainter = TextPainter(
                text: TextSpan(
                  text: item.value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: targetFontWeight,
                    fontFamily: content.fontFamily,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 1.5
                      ..color = Colors.black54,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              _strokePainterCache[strokeCacheKey] = strokePainter;
            }
            strokePainter.paint(canvas, Offset(currentX, baseY));
          }

          textPainter.paint(canvas, Offset(currentX, baseY));
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
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: fontSize,
              fontFamily: content.fontFamily,
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
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final builder =
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

    return builder.build()..layout(ui.ParagraphConstraints(width: danmakuWidth));
  }

  static void clearCache() {
    _widthCache.clear();
    _textPainterCache.clear();
    _strokePainterCache.clear();
  }
}
