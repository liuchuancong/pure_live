import '../core/barrage_config.dart';
import '../model/barrage/barrage_track.dart';
import '../model/barrage/barrage_entry.dart';

class TrackAllocator {
  const TrackAllocator();

  int allocate({
    required List<BarrageTrack> tracks,
    required BarrageEntry current,
    required double screenWidth,
    required BarrageConfig config,
  }) {
    if (tracks.isEmpty) return -1;

    int bestTrack = -1;
    double minPenalty = double.infinity;

    final int len = tracks.length;
    for (int i = 0; i < len; i++) {
      final track = tracks[i];
      if (track.locked) continue;

      if (track.activeCount == 0) {
        return i;
      }

      final last = track.lastEntry;
      if (last != null) {
        if (last.x + last.width + config.overlapSafeGap > screenWidth) {
          continue;
        }
      }

      final double penalty = track.activeCount * 10.0 + track.avgSpeed * 0.1;
      if (penalty < minPenalty) {
        minPenalty = penalty;
        bestTrack = i;
      }
    }

    return bestTrack;
  }
}
