import 'dart:ui' as ui;
import 'package:flame_barrage/flame_barrage.dart';

class MixedLayout {
  MixedLayout({required this.atlas, int maxTextCacheSize = 1000}) : _textCache = TextCache(maxSize: maxTextCacheSize);

  final EmojiAtlas atlas;
  TextCache _textCache;
  final Map<int, LayoutResult> _cache = {};
  final List<LayoutSpan> _reusableSpans = [];

  int get cacheCount => _cache.length;

  void updateMaxTextCacheSize(int newSize) {
    if (_textCache.maxSize == newSize) return;
    final newCache = TextCache(maxSize: newSize);
    _textCache.clear();
    _textCache = newCache;
    _cache.clear();
  }

  void clearCache() {
    _cache.clear();
    _textCache.clear();
  }

  LayoutResult layout(List<Fragment> fragments, {required BarrageItem item, required BarrageConfig config}) {
    final int combinedHash = _buildNumericCacheKey(fragments, config, item.priority);

    final cached = _cache[combinedHash];
    if (cached != null) {
      return cached;
    }

    final result = _layoutInternal(fragments, item, config, combinedHash);
    _cache[combinedHash] = result;

    return result;
  }

  LayoutResult _layoutInternal(List<Fragment> fragments, BarrageItem item, BarrageConfig config, int combinedHash) {
    _reusableSpans.clear();
    double currentX = 0.0;
    double maxHeight = 0.0;

    final int colorValue = config.textColor.toARGB32();
    final double fontSize = config.fontSize;
    final bool showStroke = config.showStroke;
    final List<BarrageEffectInterceptor> interceptors = config.effectInterceptors;
    final int intceptorLen = interceptors.length;

    final int len = fragments.length;
    for (int i = 0; i < len; i++) {
      final fragment = fragments[i];

      if (fragment is TextFragment) {
        final textCacheKey =
            '${fragment.text}|${config.fontSize}|$colorValue|$showStroke|${config.fontWeight.toString()}';
        final strokeCacheKey = '${fragment.text}|$fontSize|${config.strokeColor.toARGB32()}|$showStroke';

        final paragraph = _buildParagraph(fragment.text, config, textCacheKey, isStroke: false);
        final strokeParagraph = config.showStroke
            ? _buildParagraph(fragment.text, config, strokeCacheKey, isStroke: true)
            : null;

        final width = paragraph.maxIntrinsicWidth;
        final height = paragraph.height;

        if (height > maxHeight) maxHeight = height;

        dynamic matchedInterceptor;
        for (int j = 0; j < intceptorLen; j++) {
          if (interceptors[j].shouldIntercept(item, config)) {
            matchedInterceptor = interceptors[j];
            break;
          }
        }

        if (matchedInterceptor != null) {
          final customSpan = matchedInterceptor.createCustomSpan(
            item: item,
            text: fragment.text,
            paragraph: paragraph,
            x: currentX,
            y: 0.0,
            width: width,
            height: height,
            config: config,
          );
          _reusableSpans.add(customSpan);
        } else {
          _reusableSpans.add(
            TextLayoutSpan(
              x: currentX,
              y: 0.0,
              width: width,
              height: height,
              text: fragment.text,
              paragraph: paragraph,
              strokeParagraph: strokeParagraph,
            ),
          );
        }
        currentX += width;
      } else if (fragment is SpriteFragment) {
        if (config.noEmojiMode) continue;

        final emojiId = fragment.emojiId;
        final sprite = atlas.getStaticSprite(emojiId);
        if (sprite == null) continue;

        final double spriteWidth = sprite.srcSize.x;
        final double spriteHeight = sprite.srcSize.y;
        final double scale = config.emojiSize / (spriteHeight > 0 ? spriteHeight : 24.0);
        final double finalWidth = spriteWidth * scale;
        final double finalHeight = spriteHeight * scale;

        if (finalHeight > maxHeight) maxHeight = finalHeight;

        final animation = atlas.getAnimation(emojiId);
        final player = animation != null ? SpriteAnimationPlayer(animation: animation) : null;

        _reusableSpans.add(
          SpriteLayoutSpan(x: currentX, y: 0.0, width: finalWidth, height: finalHeight, sprite: sprite, player: player),
        );
        currentX += finalWidth;
      } else if (fragment is EmojiFragment) {
        if (config.noEmojiMode) continue;

        final emojiInfo = fragment.emoji;
        final image = atlas.image(emojiInfo.id);
        if (image == null) continue;

        final double width = config.emojiSize;
        final double height = config.emojiSize;

        if (height > maxHeight) maxHeight = height;

        _reusableSpans.add(EmojiLayoutSpan(x: currentX, y: 0.0, width: width, height: height, image: image));
        currentX += width;
      }
    }

    final spanLen = _reusableSpans.length;
    final finalSpans = List<LayoutSpan>.generate(spanLen, (index) {
      final span = _reusableSpans[index];
      final centeredY = (maxHeight - span.height) / 2.0;

      if (span.runtimeType != TextLayoutSpan && span is TextLayoutSpan) {
        try {
          return (span as dynamic).copyWithY(centeredY) as LayoutSpan;
        } catch (_) {
          return span;
        }
      } else if (span is TextLayoutSpan) {
        return TextLayoutSpan(
          x: span.x,
          y: centeredY,
          width: span.width,
          height: span.height,
          text: span.text,
          paragraph: span.paragraph,
          strokeParagraph: span.strokeParagraph,
        );
      } else if (span is SpriteLayoutSpan) {
        return SpriteLayoutSpan(
          x: span.x,
          y: centeredY,
          width: span.width,
          height: span.height,
          sprite: span.sprite,
          player: span.player,
        );
      } else {
        final emojiSpan = span as EmojiLayoutSpan;
        return EmojiLayoutSpan(
          x: emojiSpan.x,
          y: centeredY,
          width: emojiSpan.width,
          height: emojiSpan.height,
          image: emojiSpan.image,
        );
      }
    });

    return LayoutResult(width: currentX, height: maxHeight, spans: finalSpans, cacheKey: combinedHash.toString());
  }

  ui.Paragraph _buildParagraph(String text, BarrageConfig config, String textCacheKey, {required bool isStroke}) {
    final cached = _textCache.get(textCacheKey);
    if (cached != null) {
      return cached;
    }

    // A 1.0 line box clips the ascent of several CJK/custom fonts and also
    // leaves no room for the stroke at the top edge.  Keep a small symmetric
    // vertical allowance so glyphs remain complete at every configured size.
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: config.fontSize, height: 1.15));

    if (isStroke) {
      final strokePaint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = config.strokeWidth
        ..color = config.strokeColor
        ..isAntiAlias = true;

      builder.pushStyle(
        ui.TextStyle(
          foreground: strokePaint,
          fontSize: config.fontSize,
          fontWeight: config.fontWeight,
          fontFamily: config.fontFamily,
        ),
      );
    } else {
      final textPaint = ui.Paint()
        ..color = config.textColor
        ..isAntiAlias = true;

      builder.pushStyle(
        ui.TextStyle(
          foreground: textPaint,
          fontSize: config.fontSize,
          fontWeight: config.fontWeight,
          fontFamily: config.fontFamily,
        ),
      );
    }

    builder.addText(text);
    builder.pop();

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: double.infinity));

    _textCache.put(textCacheKey, paragraph);
    return paragraph;
  }

  int _buildNumericCacheKey(List<Fragment> fragments, BarrageConfig config, int priority) {
    int hash = 17;
    hash = 37 * hash + config.fontSize.hashCode;
    hash = 37 * hash + config.fontWeight.hashCode;
    hash = 37 * hash + config.textColor.toARGB32().hashCode;
    hash = 37 * hash + config.emojiSize.hashCode;
    hash = 37 * hash + priority.hashCode;
    hash = 37 * hash + config.showStroke.hashCode;
    hash = 37 * hash + config.strokeColor.toARGB32().hashCode;
    hash = 37 * hash + config.fontFamily.hashCode;

    final len = fragments.length;
    for (int i = 0; i < len; i++) {
      final fragment = fragments[i];
      if (fragment is TextFragment) {
        hash = 37 * hash + fragment.text.hashCode;
      } else if (fragment is SpriteFragment) {
        hash = 37 * hash + fragment.emojiId.hashCode;
      } else if (fragment is EmojiFragment) {
        hash = 37 * hash + fragment.emoji.id.hashCode;
      }
    }
    return hash;
  }
}
