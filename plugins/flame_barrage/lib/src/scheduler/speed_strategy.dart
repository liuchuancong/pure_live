import '../core/barrage_config.dart';
import '../model/barrage/barrage_track.dart';
import '../model/barrage/barrage_entry.dart';

class SpeedStrategy {
  const SpeedStrategy();

  double calculate(
    BarrageEntry current,
    double screenWidth,
    BarrageConfig config, {
    required BarrageTrack targetTrack,
  }) {
    final last = targetTrack.lastEntry;
    if (last == null) {
      return config.baseSpeed;
    }

    if (config.baseSpeed <= last.speed) {
      return config.baseSpeed;
    }

    final double lastRight = targetTrack.lastRight;
    final double catchUpDistance = screenWidth - lastRight;
    final double lastRemainingTime = lastRight / last.speed;

    if (lastRemainingTime <= 0) {
      return config.baseSpeed;
    }

    final double maxAllowedSpeed = last.speed + (catchUpDistance / lastRemainingTime);
    if (config.baseSpeed > maxAllowedSpeed) {
      return last.speed * 0.95;
    }

    return config.baseSpeed;
  }
}
