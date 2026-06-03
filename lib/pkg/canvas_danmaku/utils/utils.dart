import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class Utils {
  static final Paint _emojiPaint = Paint()..filterQuality = FilterQuality.medium;
  static final List<FontWeight> _fontWeights = FontWeight.values;

  static final Map<String, _CachedParagraph> _paragraphCache = {};
  static const int _maxCacheSize = 300;

  static String _getParagraphKey(DanmakuContentItem content, double fontSize, int fontWeight, bool showStroke) {
    return '${content.text}|$fontSize|$fontWeight|${content.color.toARGB32()}|$showStroke|${content.fontFamily ?? ""}';
  }

  static void _checkAndTrimCache() {
    if (_paragraphCache.length > _maxCacheSize) {
      _paragraphCache.clear();
    }
  }

  static ui.Paragraph generateParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    _checkAndTrimCache();
    final key = _getParagraphKey(content, fontSize, fontWeight, false);
    var cached = _paragraphCache[key];

    if (cached == null) {
      cached = _buildParagraph(content, fontSize, fontWeight, false);
      _paragraphCache[key] = cached;
    }
    return cached.mainParagraph;
  }

  static ui.Paragraph generateStrokeParagraph(
    DanmakuContentItem content,
    double danmakuWidth,
    double fontSize,
    int fontWeight,
  ) {
    _checkAndTrimCache();
    final key = _getParagraphKey(content, fontSize, fontWeight, true);
    var cached = _paragraphCache[key];

    if (cached == null) {
      cached = _buildParagraph(content, fontSize, fontWeight, true);
      _paragraphCache[key] = cached;
    }
    return cached.strokeParagraph ?? cached.mainParagraph;
  }

  static double calculateMixedContentWidth(
    DanmakuContentItem content,
    double fontSize,
    int fontWeight,
    bool showStroke,
  ) {
    final key = _getParagraphKey(content, fontSize, fontWeight, showStroke);
    var cached = _paragraphCache[key];

    if (cached == null) {
      cached = _buildParagraph(content, fontSize, fontWeight, showStroke);
      _paragraphCache[key] = cached;
    }
    return cached.width;
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
    _checkAndTrimCache();

    final key = _getParagraphKey(content, fontSize, fontWeight, showStroke);
    var cached = _paragraphCache[key];

    if (cached == null) {
      cached = _buildParagraph(content, fontSize, fontWeight, showStroke);
      _paragraphCache[key] = cached;
    }

    final double currentX = offset.dx;
    final double baseY = offset.dy;
    final drawOffset = Offset(currentX, baseY);

    if (selfSend && selfSendPaint != null) {
      canvas.drawRect(Rect.fromLTWH(currentX, baseY, cached.width, cached.height), selfSendPaint);
    }

    if (showStroke && cached.strokeParagraph != null) {
      canvas.drawParagraph(cached.strokeParagraph!, drawOffset);
    }

    canvas.drawParagraph(cached.mainParagraph, drawOffset);

    final List<ui.TextBox> inlineBoxes = cached.mainParagraph.getBoxesForPlaceholders();

    for (int i = 0; i < inlineBoxes.length && i < cached.emojiKeys.length; i++) {
      final emojiKey = cached.emojiKeys[i];
      final image = EmojiManager.getEmoji(emojiKey);

      if (image != null) {
        final box = inlineBoxes[i];
        final dstRect = Rect.fromLTWH(currentX + box.left, baseY + box.top, cached.emojiSize, cached.emojiSize);

        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dstRect,
          _emojiPaint,
        );
      }
    }
  }

  static _CachedParagraph _buildParagraph(
    DanmakuContentItem content,
    double fontSize,
    int fontWeight,
    bool showStroke,
  ) {
    final targetFontWeight = _fontWeights[fontWeight.clamp(0, _fontWeights.length - 1)];
    final double emojiSize = fontSize * 1.2;

    final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.left, textDirection: TextDirection.ltr, maxLines: 1);

    final mainBuilder = ui.ParagraphBuilder(paragraphStyle);
    final List<String> embeddedEmojis = [];

    for (final item in content.mixedContent) {
      if (item.type == ContentType.text) {
        mainBuilder.pushStyle(
          ui.TextStyle(
            color: content.color,
            fontSize: fontSize,
            fontWeight: targetFontWeight,
            fontFamily: content.fontFamily,
          ),
        );
        mainBuilder.addText(item.value);
        mainBuilder.pop();
      } else {
        mainBuilder.addPlaceholder(emojiSize, emojiSize, ui.PlaceholderAlignment.middle);
        embeddedEmojis.add(item.value);
      }
    }
    final mainParagraph = mainBuilder.build();
    mainParagraph.layout(const ui.ParagraphConstraints(width: double.infinity));

    ui.Paragraph? strokeParagraph;
    if (showStroke) {
      final strokeBuilder = ui.ParagraphBuilder(paragraphStyle);
      for (final item in content.mixedContent) {
        if (item.type == ContentType.text) {
          strokeBuilder.pushStyle(
            ui.TextStyle(
              fontSize: fontSize,
              fontWeight: targetFontWeight,
              fontFamily: content.fontFamily,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (fontWeight.toDouble() * 0.5).clamp(1.0, 5.0)
                ..color = Colors.black,
            ),
          );
          strokeBuilder.addText(item.value);
          strokeBuilder.pop();
        } else {
          strokeBuilder.addPlaceholder(emojiSize, emojiSize, ui.PlaceholderAlignment.middle);
        }
      }
      strokeParagraph = strokeBuilder.build();
      strokeParagraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    }

    return _CachedParagraph(
      mainParagraph: mainParagraph,
      strokeParagraph: strokeParagraph,
      width: mainParagraph.longestLine,
      height: mainParagraph.height,
      emojiKeys: embeddedEmojis,
      emojiSize: emojiSize,
    );
  }

  static void clearCache() {
    _paragraphCache.clear();
  }
}

class _CachedParagraph {
  final ui.Paragraph mainParagraph;
  final ui.Paragraph? strokeParagraph;
  final double width;
  final double height;
  final List<String> emojiKeys;
  final double emojiSize;

  _CachedParagraph({
    required this.mainParagraph,
    required this.strokeParagraph,
    required this.width,
    required this.height,
    required this.emojiKeys,
    required this.emojiSize,
  });
}
