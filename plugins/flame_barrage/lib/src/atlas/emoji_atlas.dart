import 'dart:ui' as ui;
import 'atlas_loader.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import '../cache/atlas_cache.dart';
import '../cache/sprite_cache.dart';
import 'sprite_sheet.dart' as local;
import 'package:flame_barrage/src/model/emoji/emoji_info.dart';
import 'package:flame_barrage/src/model/emoji/emogi_source_type.dart';

class EmojiAtlas {
  EmojiAtlas._();

  static final EmojiAtlas instance = EmojiAtlas._();

  final Map<String, EmojiInfo> _emojiMap = {};
  final Map<String, ui.Rect> _atlasRectMap = {};
  final Map<String, SpriteAnimation> _animationCache = {};

  final AtlasCache _atlasCache = AtlasCache();
  final SpriteCache _spriteCache = SpriteCache();
  final AtlasLoader _loader = const AtlasLoader();

  RegExp? _regex;

  RegExp? get regex => _regex;
  int get count => _emojiMap.length;
  bool get isEmpty => _emojiMap.isEmpty;

  void register(EmojiInfo info) {
    for (final key in info.keys) {
      _emojiMap[key] = info;
    }
    _rebuildRegex();
  }

  void registerAll(List<EmojiInfo> list) {
    final len = list.length;
    for (int i = 0; i < len; i++) {
      register(list[i]);
    }
  }

  void updateAtlasRects(Map<String, ui.Rect> rects) {
    _atlasRectMap.addAll(rects);
  }

  EmojiInfo? find(String key) => _emojiMap[key];

  ui.Image? image(String emojiId) => _atlasCache.get(emojiId);

  SpriteAnimation? getAnimation(String emojiId) => _animationCache[emojiId];

  ui.Rect? getSrcRect(String emojiId) => _atlasRectMap[emojiId];

  Sprite? getStaticSprite(String emojiId) => _spriteCache.get(emojiId);

  void _rebuildRegex() {
    if (_emojiMap.isEmpty) {
      _regex = null;
      return;
    }
    final keys = _emojiMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    _regex = RegExp(keys.map(RegExp.escape).join('|'));
  }

  void resolveLoadedImage(EmojiInfo info, ui.Image img) {
    _atlasCache.put(info.id, img);

    if (info.sourceType == EmojiSourceType.animated) {
      final frameCount = (img.width / info.width).floor();
      final finalCount = frameCount < 1 ? 1 : frameCount;

      final sheet = local.SpriteSheet(
        imageWidth: img.width.toDouble(),
        imageHeight: img.height.toDouble(),
        rows: 1,
        columns: finalCount,
      );

      final rects = sheet.generateAllRects();
      final flameSpriteSheet = SpriteSheet(image: img, srcSize: Vector2(sheet.srcWidth, sheet.srcHeight));

      final animation = flameSpriteSheet.createAnimation(row: 0, stepTime: 0.1, to: finalCount);

      _animationCache[info.id] = animation;

      final firstRect = rects.first;
      final firstSprite = Sprite(
        img,
        srcPosition: Vector2(firstRect.left, firstRect.top),
        srcSize: Vector2(firstRect.width, firstRect.height),
      );
      _spriteCache.put(info.id, firstSprite);
    } else if (info.sourceType == EmojiSourceType.atlas) {
      _atlasRectMap.forEach((emojiId, rect) {
        final atlasSprite = Sprite(
          img,
          srcPosition: Vector2(rect.left, rect.top),
          srcSize: Vector2(rect.width, rect.height),
        );
        _spriteCache.put(emojiId, atlasSprite);
      });
    } else {
      _atlasRectMap[info.id] = ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final fullSprite = Sprite(
        img,
        srcPosition: Vector2.zero(),
        srcSize: Vector2(img.width.toDouble(), img.height.toDouble()),
      );
      _spriteCache.put(info.id, fullSprite);
    }
  }

  Future<void> preloadEmoji(EmojiInfo info) async {
    try {
      final img = await _loader.loadFromAsset(info.asset);
      resolveLoadedImage(info, img);
    } catch (_) {}
  }

  Future<void> preloadAll() async {
    final loaded = <String>{};
    for (final emoji in _emojiMap.values) {
      if (loaded.contains(emoji.id)) continue;
      loaded.add(emoji.id);
      await preloadEmoji(emoji);
    }
  }

  void clear() {
    _emojiMap.clear();
    _animationCache.clear();
    _atlasRectMap.clear();
    _atlasCache.clear();
    _spriteCache.clear();
    _regex = null;
  }
}
