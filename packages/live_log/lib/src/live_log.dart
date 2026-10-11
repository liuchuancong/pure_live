import 'package:live_log/src/context.dart';
import 'package:live_log/src/dispatcher.dart';
import 'package:live_log/src/filter.dart';
import 'package:live_log/src/level.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sanitizer.dart';
import 'package:live_log/src/sink.dart';

/// State shared by every view of one `LiveLog` tree.
final class _SharedState {
  new({required this.dispatcher, required this.filter, required this.sanitizer});

  final LogDispatcher dispatcher;
  final LogFilter filter;
  final LogSanitizer sanitizer;
  int sequence = 0;
}

/// The logging facade: one tree of category views over a shared sink list.
///
/// Create the process root once and hand out views:
///
/// ```dart
/// final log = LiveLog.root(sinks: [MemorySink()]);
/// final netLog = log.forCategory('live_net');        // live_net
/// final socketLog = netLog.forCategory('socket');    // live_net.socket
/// socketLog.debug('frame decoded', fields: {'size': 42});
/// ```
///
/// Emitting is guarded twice: the tree filter decides whether building the
/// record is worth it at all (pass a `String Function()` as the message for
/// expensive construction), and each sink binding applies its own minimum
/// level on the way out. Messages and fields are sanitised at emit time;
/// the error object and stack trace are redacted by the formatters.
final class LiveLog {
  /// Creates the process root. `sinks` elements may be bare `LogSink`s or
  /// [SinkBinding]s; [minLevel] and [categoryMinLevels] form the tree's
  /// [LogFilter].
  new root({
    List<Object> sinks = const [],
    LogLevel minLevel = LogLevel.info,
    Map<String, LogLevel> categoryMinLevels = const {},
    LogSanitizer sanitizer = const LogSanitizer(),
  }) : this._(
         _SharedState(
           dispatcher: LogDispatcher(sinks: sinks),
           filter: LogFilter(minLevel: minLevel, categoryMinLevels: Map.of(categoryMinLevels)),
           sanitizer: sanitizer,
         ),
         LogContext.empty,
         category: '',
       );

  new _(this._state, this._context, {required this.category});

  final _SharedState _state;
  bool _closed = false;

  /// Full category path of this view; empty for the root.
  final String category;

  final LogContext _context;

  /// A view under this one: `sites.forCategory('bilibili')` on the root
  /// yields category `sites.bilibili`. Views share the tree's sinks,
  /// filter and sequence counter; closing any view closes the whole tree.
  LiveLog forCategory(String name) {
    final path = category.isEmpty ? name : '$category.$name';
    return LiveLog._(_state, _context, category: path);
  }

  /// A view whose [LogContext] carries [fields] on top of this view's;
  /// call-site fields still win over context values at emit time.
  LiveLog withContext(Map<String, Object?> fields) =>
      LiveLog._(_state, _context.merge(LogContext(fields)), category: category);

  /// Adjusts the tree's level policy: the default level, or an exact-path
  /// category override when [category] is given.
  void setMinLevel(LogLevel level, {String? category}) => _state.filter.setMinLevel(level, category: category);

  /// Hot-swaps [oldSink] for [newSink]; the next record goes to the new
  /// sink, and the old one is closed in the background (draining its
  /// queue) so nothing is lost.
  ///
  /// This is how "user changed the log directory in settings" takes effect
  /// immediately: build a `FileSink` on the new directory and swap it in.
  /// The new sink inherits the old binding's minimum level unless
  /// [minLevel] says otherwise. Returns whether [oldSink] was part of this
  /// tree; a closed tree refuses the swap and returns false.
  bool replaceSink(LogSink oldSink, LogSink newSink, {LogLevel? minLevel}) {
    if (_closed) {
      return false;
    }
    return _state.dispatcher.replaceSink(oldSink, newSink, minLevel: minLevel);
  }

  /// Whether a record at [level] from this view would be emitted.
  bool isLoggable(LogLevel level) => !_closed && _state.filter.isLoggable(level, category);

  /// Emits a record at [level] from this view's category.
  ///
  /// [message] is either a [String] or a `String Function()` — the latter
  /// is evaluated only after the level check passes, so filtered calls
  /// never pay for building their text. [fields] are merged over the
  /// view's context; [error] and [stackTrace] ride along raw and are
  /// redacted by the formatters.
  void log(
    LogLevel level,
    Object message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isLoggable(level)) {
      return;
    }
    final text = message is String ? message : (message as String Function())();
    final sanitizer = _state.sanitizer;
    final record = LogRecord(
      level: level,
      category: category,
      message: sanitizer.sanitizeText(text),
      fields: _mergeFields(sanitizer, fields),
      error: error,
      stackTrace: stackTrace,
      sequence: _state.sequence++,
    );
    _state.dispatcher.dispatch(record);
  }

  /// Emits at [LogLevel.trace].
  void trace(Object message, {Map<String, Object?> fields = const {}}) => log(LogLevel.trace, message, fields: fields);

  /// Emits at [LogLevel.debug].
  void debug(Object message, {Map<String, Object?> fields = const {}}) => log(LogLevel.debug, message, fields: fields);

  /// Emits at [LogLevel.info].
  void info(Object message, {Map<String, Object?> fields = const {}}) => log(LogLevel.info, message, fields: fields);

  /// Emits at [LogLevel.warning].
  void warning(Object message, {Map<String, Object?> fields = const {}}) =>
      log(LogLevel.warning, message, fields: fields);

  /// Emits at [LogLevel.error], carrying [error] and its [stackTrace].
  void error(Object message, {Map<String, Object?> fields = const {}, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, fields: fields, error: error, stackTrace: stackTrace);

  /// Emits at [LogLevel.fatal], carrying [error] and its [stackTrace].
  void fatal(Object message, {Map<String, Object?> fields = const {}, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.fatal, message, fields: fields, error: error, stackTrace: stackTrace);

  /// Closes every sink; the whole tree goes quiet. Later emits are no-ops.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _state.dispatcher.close();
  }

  Map<String, Object?> _mergeFields(LogSanitizer sanitizer, Map<String, Object?> fields) {
    if (_context.isEmpty && fields.isEmpty) {
      return const {};
    }
    // Context values and call-site values are redacted through the same
    // single entry point; call-site keys win over context keys.
    return sanitizer.sanitizeFields({..._context.fields, ...fields});
  }
}
