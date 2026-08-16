//MIT License
//
//Copyright (c) [2019-2020] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

part of fijkplayer;

/// Log level for the [FijkLog.log] method.
@immutable
class FijkLogLevel {
  final int level;
  final String name;

  const FijkLogLevel._(int l, String n)
      : level = l,
        name = n;

  /// Priority constant for the [FijkLog.log] method;
  static const FijkLogLevel All = FijkLogLevel._(000, 'all');

  /// Priority constant for the [FijkLog.log] method;
  static const FijkLogLevel Detail = FijkLogLevel._(100, 'det');

  /// Priority constant for the [FijkLog.log] method;
  static const FijkLogLevel Verbose = FijkLogLevel._(200, 'veb');

  /// Priority constant for the [FijkLog.log] method; use [FijkLog.d(msg)]
  static const FijkLogLevel Debug = FijkLogLevel._(300, 'dbg');

  /// Priority constant for the [FijkLog.log] method; use [FijkLog.i(msg)]
  static const FijkLogLevel Info = FijkLogLevel._(400, 'inf');

  /// Priority constant for the [FijkLog.log] method; use [FijkLog.w(msg)]
  static const FijkLogLevel Warn = FijkLogLevel._(500, 'war');

  /// Priority constant for the [FijkLog.log] method; use [FijkLog.e(msg)]
  static const FijkLogLevel Error = FijkLogLevel._(600, 'err');
  static const FijkLogLevel Fatal = FijkLogLevel._(700, 'fal');
  static const FijkLogLevel Silent = FijkLogLevel._(800, 'sil');

  @override
  String toString() {
    return 'FijkLogLevel{level:$level, name:$name}';
  }
}

/// API for sending log output
///
/// Generally, you should use the [FijkLog.d(msg)], [FijkLog.i(msg)],
/// [FijkLog.w(msg)], and [FijkLog.e(msg)] methods to write logs.
/// You can then view the logs in console/logcat.
///
/// The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE.
/// Verbose should always be skipped in an application except during development.
/// Debug logs are compiled in but stripped at runtime.
/// Error, warning and info logs are always kept.
class FijkLog {
  static FijkLogLevel _level = FijkLogLevel.Info;

  /// Make constructor private
  const FijkLog._();

  /// Set global whole log level
  ///
  /// Call this method on Android platform will load natvie shared libraries.
  /// If you care about app boot performance,
  /// you should call this method as late as possiable. Call this method before the first time you consturctor new [FijkPlayer]
  static setLevel(final FijkLogLevel level) {
    _level = level;
    log(FijkLogLevel.Silent, "set log level $level", "fijk");
    FijkPlugin._setLogLevel(level.level).then((_) {
      log(FijkLogLevel.Silent, "native log level ${level.level}", "fijk");
    });
  }

  /// log [msg] with [level] and [tag] to console
  static log(FijkLogLevel level, String msg, String tag) {
    if (level.level >= _level.level) {
      DateTime now = DateTime.now();
      print("[${level.name}] ${now.toLocal()} [$tag] $msg");
    }
  }

  /// log [msg] with [FijkLogLevel.Verbose] level
  static v(String msg, {String tag = 'fijk'}) {
    log(FijkLogLevel.Verbose, msg, tag);
  }

  /// log [msg] with [FijkLogLevel.Debug] level
  static d(String msg, {String tag = 'fijk'}) {
    log(FijkLogLevel.Debug, msg, tag);
  }

  /// log [msg] with [FijkLogLevel.Info] level
  static i(String msg, {String tag = 'fijk'}) {
    log(FijkLogLevel.Info, msg, tag);
  }

  /// log [msg] with [FijkLogLevel.Warn] level
  static w(String msg, {String tag = 'fijk'}) {
    log(FijkLogLevel.Warn, msg, tag);
  }

  /// log [msg] with [FijkLogLevel.Error] level
  static e(String msg, {String tag = 'fijk'}) {
    log(FijkLogLevel.Error, msg, tag);
  }
}
