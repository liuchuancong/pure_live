import 'dart:developer' as developer;

class BarrageLogger {
  static int logLevel = 1;

  static void d(String tag, String message) {
    if (logLevel <= 0) {
      developer.log(message, name: 'BarrageEngine::D::$tag');
    }
  }

  static void i(String tag, String message) {
    if (logLevel <= 1) {
      developer.log(message, name: 'BarrageEngine::I::$tag');
    }
  }

  static void w(String tag, String message) {
    if (logLevel <= 2) {
      developer.log(message, name: 'BarrageEngine::W::$tag');
    }
  }

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (logLevel <= 3) {
      developer.log(message, name: 'BarrageEngine::E::$tag', error: error, stackTrace: stackTrace);
    }
  }
}
