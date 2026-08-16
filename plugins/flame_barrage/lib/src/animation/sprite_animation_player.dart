import 'dart:ui';
import 'package:flame/sprite.dart';

class SpriteAnimationPlayer {
  SpriteAnimationPlayer({required this.animation}) : _ticker = animation.createTicker();

  final SpriteAnimation animation;
  final SpriteAnimationTicker _ticker;

  bool get done => _ticker.done();

  void update(double dt) {
    _ticker.update(dt);
  }

  void reset() {
    _ticker.reset();
  }

  void paint(Canvas canvas, Rect dstRect, Paint paint) {
    final sprite = _ticker.getSprite();
    final image = sprite.image;

    final srcRect = Rect.fromLTWH(sprite.srcPosition.x, sprite.srcPosition.y, sprite.srcSize.x, sprite.srcSize.y);

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }
}
