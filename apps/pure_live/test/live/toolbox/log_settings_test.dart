import 'dart:io' show Directory;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_log/live_log.dart' show LogLevel, LogRecord;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/logging/app_log.dart';

/// The log tree's own core: the safe file name, the stored settings and
/// their clamps across a re-read, and the three ways the records leave —
/// the clipboard text, and the saved copy's three encodings.
void main() {
  late StorageStores stores;
  late Directory temp;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    temp = await Directory.systemTemp.createTemp('pure_live_log_test');
    // The layout's answer moves every test's sink to its own folder; the
    // re-read lands the store's (fresh) defaults on the tree.
    applyAppLogDirectory(temp);
    syncAppLogFromStore();
    setAppLogFileEnabled(enabled: false);
  });

  tearDown(() async {
    setAppLogFileEnabled(enabled: false);
    await temp.delete(recursive: true);
    await stores.close();
  });

  test('a viewer-typed name sheds what a file cannot carry', () {
    expect(normalizeAppLogBaseName('my:log/name?'), 'mylogname');
    expect(normalizeAppLogBaseName('  spaced  '), 'spaced');
    expect(normalizeAppLogBaseName(''), kDefaultAppLogBaseName);
    expect(normalizeAppLogBaseName('   '), kDefaultAppLogBaseName);
    final long = normalizeAppLogBaseName('l' * 50);
    expect(long.length, kAppLogBaseNameMaxLength);
    expect(normalizeAppLogBaseName('${'l' * 39}   '), 'l' * 39); // the cut trims its tail
  });

  test('every setting writes through and re-reads the same', () async {
    setAppLogLevel(LogLevel.warning);
    setAppLogFileEnabled(enabled: true);
    setAppLogFileMaxBytes(2 * 1024 * 1024);
    setAppLogFilesKept(5);
    setAppLogBaseName('my run');
    setAppLogExportFormat(LogExportFormat.jsonLines);

    expect(appLogLevel, LogLevel.warning);
    expect(appLogFileEnabled, isTrue);
    expect(appLogFileMaxBytes, 2 * 1024 * 1024);
    expect(appLogFilesKept, 5);
    expect(appLogBaseName, 'my run');
    expect(appLogExportFormat, LogExportFormat.jsonLines);

    // The store holds them; a re-read lands the same tree.
    await pumpEventQueue(); // the preference writes travel without a waiter
    expect(StoragePrefs.getString('log.level'), 'warning');
    syncAppLogFromStore();
    expect(appLogLevel, LogLevel.warning);
    expect(appLogFilesKept, 5);
    expect(appLogBaseName, 'my run');
    expect(appLogExportFormat, LogExportFormat.jsonLines);
  });

  test('the kept-files count clamps, the same-cap writes nothing', () async {
    setAppLogFilesKept(999);
    expect(appLogFilesKept, 100);
    await pumpEventQueue();
    expect(StoragePrefs.getInt('log.filesKept'), 100);

    setAppLogFilesKept(-3);
    expect(appLogFilesKept, 0);

    // The same number again is no write and no rebuild.
    setAppLogFilesKept(0);
    expect(appLogFilesKept, 0);
  });

  test('the name setter normalizes and skips the no-op', () {
    setAppLogBaseName('bad/name');
    expect(appLogBaseName, 'badname');
    setAppLogBaseName('bad/name'); // the same name again is nothing
    expect(appLogBaseName, 'badname');
  });

  group('the records leaving', () {
    setUp(() {
      appLogMemory
        ..write(LogRecord(level: LogLevel.info, category: 'probe', message: 'hello probe'))
        ..write(LogRecord(level: LogLevel.warning, category: 'room', message: 'watch out'));
    });

    test('the clipboard text carries the lines', () {
      final text = exportAppLog();
      expect(text, contains('hello probe'));
      expect(text, contains('watch out'));

      clearAppLog();
      expect(exportAppLog().trim(), isEmpty);
    });

    test('the saved copy takes the day folder and the chosen encoding', () async {
      final file = await saveAppLogCopy();
      expect(file.existsSync(), isTrue);
      expect(file.uri.pathSegments.last, endsWith('.txt'));
      expect(file.parent.path, contains(appLogDay));
      expect(file.readAsStringSync(), contains('hello probe'));

      // The .log name and the json-lines body follow the format.
      setAppLogExportFormat(LogExportFormat.log);
      expect((await saveAppLogCopy()).uri.pathSegments.last, endsWith('.log'));

      setAppLogExportFormat(LogExportFormat.jsonLines);
      final jsonl = await saveAppLogCopy();
      expect(jsonl.uri.pathSegments.last, endsWith('.jsonl'));
      expect(jsonl.readAsStringSync(), contains('watch out'));
    });
  });
}
