import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame_barrage/flame_barrage.dart';

class BarrageComponent extends PositionComponent with HasGameReference<BarrageEngine> {
  BarrageComponent({required this.entry, required this.picture, required this.fixedDuration})
    : _fixedDurationSeconds = fixedDuration.inMilliseconds / 1000.0 {
    size = Vector2(entry.width, entry.height);
    position = Vector2(entry.x, entry.y);
  }

  BarrageEntry entry;
  Picture picture;
  Duration fixedDuration;
  double opacity = 1.0;
  double _lifeTimer = 0.0;
  double _fixedDurationSeconds;

  void reset({
    required BarrageEntry newEntry,
    required Picture newPicture,
    required Duration newFixedDuration,
  }) {
    entry = newEntry;
    picture = newPicture;
    fixedDuration = newFixedDuration;
    _fixedDurationSeconds = newFixedDuration.inMilliseconds / 1000.0;
    _lifeTimer = 0.0;
    opacity = 1.0;
    size.setValues(newEntry.width, newEntry.height);
    position.setValues(newEntry.x, newEntry.y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final itemType = entry.item.type;

    if (itemType == BarrageType.scroll) {
      final newX = position.x - entry.speed * dt;
      position.x = newX;
      entry.x = newX;

      if (newX + size.x < 0) {
        removeFromParent();
      }
      return;
    }

    _lifeTimer += dt;
    if (_lifeTimer >= _fixedDurationSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0.0) return;
    canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    if (game.isMounted) {
      game.recycleComponent(entry);
    }
    super.onRemove();
  }
}
