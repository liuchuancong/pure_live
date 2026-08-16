import 'package:flame_barrage/src/model/barrage/barrage_entry.dart';

class OverlapDetector {
  const OverlapDetector();

  bool canEnter(BarrageEntry current, BarrageEntry last, double screenWidth, {required double safeGap}) {
    final double lastTailX = last.x + last.width;

    if (lastTailX + safeGap > screenWidth) {
      return false;
    }

    if (current.speed > last.speed) {
      final double realRelativeDistance = screenWidth - lastTailX;
      final double catchUpTime = realRelativeDistance / (current.speed - last.speed);
      final double lastRemainingTime = lastTailX / last.speed;

      if (catchUpTime - (safeGap / current.speed) < lastRemainingTime) {
        return false;
      }
    }

    return true;
  }
}
