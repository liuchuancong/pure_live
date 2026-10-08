// Module: test/logger_test.dart
// Purpose: Verify level filtering, hierarchical names, prefix overrides and field redaction in pure_live_logging.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:test/test.dart';

void main() {
  test('test_logger_belowThreshold_writesNothing', () {
    final sink = MemoryLogSink();
    final log = LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.warning).logger('app');

    log.debug('noise');
    log.info('also noise');
    log.warning('kept');

    expect(sink.records, hasLength(1));
    expect(sink.records.single.level, LogLevel.warning);
  });

  test('test_logger_error_keepsErrorAndStack', () {
    final sink = MemoryLogSink();
    final log = LogRouter(sinks: <LogSink>[sink]).logger('network');

    log.error('request failed', error: StateError('boom'), stackTrace: StackTrace.current);

    final record = sink.records.single;
    expect(record.error, isA<StateError>());
    expect(record.stackTrace, isNotNull);
    expect(record.isErrorOrWorse, isTrue);
  });

  test('test_logger_named_appendsToThePath', () {
    final sink = MemoryLogSink();
    final root = LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug).logger('network');

    root.named('dio').named('retry').debug('attempt');

    expect(sink.records.single.logger, 'network.dio.retry');
  });

  test('test_logRouter_prefixOverride_longestMatchWins', () {
    final sink = MemoryLogSink();
    final router = LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.info)
      ..setLevel('network', LogLevel.warning)
      ..setLevel('network.dio', LogLevel.debug);

    router.logger('network').debug('dropped');
    router.logger('network').info('dropped');
    router.logger('network.dio').debug('kept');
    router.logger('network.other').info('still dropped');
    router.logger('network.other').warning('kept');

    // The longest matching prefix wins for dio, while other network children inherit the warning floor.
    expect(sink.records.map((record) => record.logger), <String>['network.dio', 'network.other']);
    expect(sink.records.last.level, LogLevel.warning);
  });

  test('test_logRecord_headerFields_areRedactedAtConstruction', () {
    // docs/contracts/platform-models.md section 16: a sink must never receive a credential.
    final record = LogRecord(
      timestamp: DateTime.utc(2026, 10, 8),
      level: LogLevel.info,
      logger: 'network',
      message: 'outgoing',
      fields: <String, Object?>{
        'requestHeaders': <String, String>{'Authorization': 'Bearer secret', 'Accept': 'application/json'},
      },
    );

    final headers = record.fields['requestHeaders']! as Map<String, String>;
    expect(headers['Authorization'], '***');
    expect(headers['Accept'], 'application/json');
  });

  test('test_logRecord_signedUrlField_isRedacted', () {
    final record = LogRecord(
      timestamp: DateTime.utc(2026, 10, 8),
      level: LogLevel.info,
      logger: 'resolver',
      message: 'resolved',
      fields: <String, Object?>{'playUrl': 'https://example.com/v.m3u8?token=abc&expires=170'},
    );

    final url = record.fields['playUrl']! as String;
    expect(url, contains('token=***'));
    expect(url, isNot(contains('abc')));
  });

  test('test_logRecord_fields_areNotMutableByTheCaller', () {
    final mutable = <String, Object?>{'a': 1};
    final record = LogRecord(
      timestamp: DateTime.utc(2026, 10, 8),
      level: LogLevel.info,
      logger: 'x',
      message: 'm',
      fields: mutable,
    );

    expect(() => mutable['b'] = 2, returnsNormally);
    expect(() => (record.fields['b'] = 2), throwsA(isA<UnsupportedError>()));
  });

  test('test_logRecord_timestamp_isNormalizedToUtc', () {
    final local = DateTime(2026, 10, 8, 6);
    final record = LogRecord(
      timestamp: local,
      level: LogLevel.info,
      logger: 'x',
      message: 'm',
    );

    // A log line in local time cannot be ordered across devices, so the record normalizes on entry.
    expect(record.timestamp.isUtc, isTrue);
    expect(record.timestamp, local.toUtc());
    expect(record.toJson()['timestamp'], local.toUtc().toIso8601String());
  });

  test('test_formatRecord_includesLevelLoggerAndMessage', () {
    final record = LogRecord(
      timestamp: DateTime.utc(2026, 10, 8, 1),
      level: LogLevel.warning,
      logger: 'recorder',
      message: 'disk low',
    );

    final line = formatRecord(record);
    expect(line, contains('WARNING'));
    expect(line, contains('[recorder]'));
    expect(line, contains('disk low'));
  });

  test('test_logLevelFromName_knownAndUnknown_returnAsDocumented', () {
    expect(logLevelFromName('warning'), LogLevel.warning);
    // Config files disagree about case, so the parse is case-insensitive; an unknown name still yields
    // null rather than a guessed level.
    expect(logLevelFromName('WARNING'), LogLevel.warning);
    expect(logLevelFromName('nope'), isNull);
    expect(logLevelFromName(null), isNull);
  });
}
