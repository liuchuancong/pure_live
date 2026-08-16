import 'dart:ui' as ui;
import 'layout_span.dart';
import 'package:flame/sprite.dart';
import '../animation/sprite_animation_player.dart';
import 'package:flame/components.dart' show Vector2;

class SpriteLayoutSpan extends LayoutSpan {
  const SpriteLayoutSpan({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.sprite,
    this.player,
  });

  final Sprite sprite;
  final SpriteAnimationPlayer? player;

  static final ui.Paint _sharedSpritePaint = ui.Paint()
    ..isAntiAlias = true
    ..filterQuality = ui.FilterQuality.medium;

  @override
  void paint(ui.Canvas canvas) {
    final dstRect = ui.Rect.fromLTWH(x, y, width, height);

    if (player != null) {
      player!.paint(canvas, dstRect, _sharedSpritePaint);
    } else {
      sprite.render(canvas, position: Vector2(x, y), size: Vector2(width, height), overridePaint: _sharedSpritePaint);
    }
  }
}
