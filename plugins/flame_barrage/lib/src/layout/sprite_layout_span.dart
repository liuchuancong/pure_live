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
    this.opacity = 1.0,
  });

  final Sprite sprite;
  final SpriteAnimationPlayer? player;
  final double opacity;

  @override
  void paint(ui.Canvas canvas) {
    final dstRect = ui.Rect.fromLTWH(x, y, width, height);
    // This paint is recorded only when a new cached barrage Picture is built,
    // not on every display frame. Baking alpha here avoids a saveLayer for
    // every visible message at 60/120 Hz.
    final paint = ui.Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.medium
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());

    if (player != null) {
      player!.paint(canvas, dstRect, paint);
    } else {
      sprite.render(
        canvas,
        position: Vector2(x, y),
        size: Vector2(width, height),
        overridePaint: paint,
      );
    }
  }
}
