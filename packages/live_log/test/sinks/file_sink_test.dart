import 'dart:io';

import 'package:live_log/live_log.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The file sink is reusable infrastructure: the host application supplies
/// its own namespace as `FileSink.baseName` — here the neutral `unit_host`
/// — and the sink writes `<baseName>.log` plus rotation files.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('live_log_file_sink_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  LogRecord record(String message) => LogRecord(level: LogLevel.info, category: 'test.feature', message: message);

  group('FileSink', () {
    test('names its live file after the host-supplied baseName', () async {
      final sink = FileSink(tempDir, baseName: 'unit_host')
        ..write(record('hello host'))
        ..write(record('host, once more'));

      await sink.flushed;
      await sink.close();

      expect(sink.currentFile.path, p.join(tempDir.path, 'unit_host.log'));
      expect(sink.currentFile.existsSync(), isTrue);
      expect(sink.currentFile.readAsStringSync(), contains('hello host'));
      expect(sink.isDegraded, isFalse);
    });

    test('rotates into <baseName>.<index>.log files', () async {
      // The tight byte budget rotates the first lines onto
      // `<baseName>.1.log` while a fresh live file keeps the rest.
      final sink = FileSink(tempDir, baseName: 'unit_host', maxFileBytes: 120, maxFiles: 3);

      for (var index = 0; index < 4; index++) {
        sink.write(record('rotation line $index'));
      }
      await sink.flushed;
      await sink.close();

      final rotated = File(p.join(tempDir.path, 'unit_host.1.log'));
      expect(rotated.existsSync(), isTrue);
      expect(rotated.readAsStringSync(), contains('rotation line 0'));
      expect(sink.currentFile.existsSync(), isTrue);
      expect(sink.currentFile.readAsStringSync(), contains('rotation line 3'));
      expect(rotated.readAsStringSync(), isNot(contains('rotation line 3')));
    });

    test('keeps every rotated file when maxFiles is zero', () async {
      // No count limit: each rotation shifts the files up one index, and the
      // oldest line is still on disk instead of falling off the edge.
      final sink = FileSink(tempDir, baseName: 'unit_host', maxFileBytes: 120, maxFiles: 0);

      for (var index = 0; index < 20; index++) {
        sink.write(record('unlimited line $index'));
      }
      await sink.flushed;
      await sink.close();

      final rotated = [
        for (final file in tempDir.listSync().whereType<File>())
          if (p.basename(file.path) != 'unit_host.log') file,
      ];
      expect(rotated.length, greaterThanOrEqualTo(3));
      expect(rotated.map((file) => file.readAsStringSync()).join(), contains('unlimited line 0'));
    });
  });
}
