import 'dart:io';

import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `PathInsights` is the planning-time probe: existence, shape and size
/// answered synchronously without creating or changing anything.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_insights');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('a missing path exists neither as file nor directory', () {
    final ghost = '${root.path}/ghost';

    expect(PathInsights.exists(ghost), isFalse);
    expect(PathInsights.isDirectory(ghost), isFalse);
    expect(PathInsights.isFile(ghost), isFalse);
    expect(PathInsights.fileSize(ghost), isNull);
  });

  test('a directory and a file are told apart', () {
    final directory = Directory('${root.path}/dir')..createSync();
    final file = File('${root.path}/file.txt')..writeAsStringSync('12345');

    expect(PathInsights.exists(directory.path), isTrue);
    expect(PathInsights.isDirectory(directory.path), isTrue);
    expect(PathInsights.isFile(directory.path), isFalse);

    expect(PathInsights.exists(file.path), isTrue);
    expect(PathInsights.isFile(file.path), isTrue);
    expect(PathInsights.isDirectory(file.path), isFalse);
    expect(PathInsights.fileSize(file.path), 5);
  });
}
