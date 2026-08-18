import 'barrage_logger.dart';

class Measure {
  const Measure._();

  static T profile<T>(String label, T Function() action) {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      if (stopwatch.elapsedMicroseconds > 1000) {
        BarrageLogger.w(
          'Performance',
          '$label 耗时较长: ${stopwatch.elapsedMicroseconds} μs (${stopwatch.elapsedMilliseconds} ms)',
        );
      } else {
        BarrageLogger.d('Performance', '$label 耗时: ${stopwatch.elapsedMicroseconds} μs');
      }
    }
  }
}
