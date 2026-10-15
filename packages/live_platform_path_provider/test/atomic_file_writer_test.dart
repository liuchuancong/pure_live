import 'dart:convert';
import 'dart:io';

import 'package:live_platform_path_provider/live_platform_path_provider.dart';

import 'package:test/test.dart';

/// `AtomicFileWriter` is what stands between a power loss and a corrupt library,
/// so the cases below are about its two promises: the target is either fully replaced
/// or untouched, and nothing is left behind in the user's directory while doing it.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_atomic');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  List<String> strayTempFiles() => root
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.startsWith('.pure_live_tmp'))
      .toList();

  test('the bytes land and the target exists afterwards', () async {
    const payload = 'channel list v1';
    final target = File('${root.path}/library.txt');

    final written = await AtomicFileWriter.writeString(target, payload);

    expect(written.existsSync(), isTrue);
    expect(written.readAsStringSync(), payload);
  });

  test('missing parent directories are created on the way', () async {
    final target = File('${root.path}/deep/nested/dirs/settings.json');

    await AtomicFileWriter.writeString(target, '{"a":1}');

    expect(target.existsSync(), isTrue);
    expect(target.readAsStringSync(), '{"a":1}');
  });

  test('a shorter replacement leaves no tail of the previous content', () async {
    final target = File('${root.path}/playlist.m3u');
    await AtomicFileWriter.writeString(target, 'first line\nsecond line\nthird line\n');

    await AtomicFileWriter.writeString(target, 'only\n');

    // The value of the temp-file dance: a naive in-place write that reuses the file
    // handle would leave the remainder of the old bytes behind, and a playlist with
    // a phantom tail is a parse error the user cannot see or fix.
    expect(target.readAsStringSync(), 'only\n');
    expect(target.lengthSync(), utf8.encode('only\n').length);
  });

  test('a successful write leaves no temp file in the directory', () async {
    final target = File('${root.path}/state.bin');

    for (var round = 0; round < 5; round++) {
      await AtomicFileWriter.writeBytes(target, utf8.encode('round $round'));
    }

    expect(strayTempFiles(), isEmpty, reason: 'a temp file per write slowly fills the storage directory');
  });

  test('a write that cannot proceed reports a platform error, not a raw file system exception', () async {
    // A file used as a parent directory cannot be created, so the write fails before
    // anything is promoted; callers are promised the PlatformException hierarchy.
    final blocker = File('${root.path}/blocker');
    await blocker.writeAsString('not a directory');
    final target = File('${root.path}/blocker/sub/data.txt');

    await expectLater(AtomicFileWriter.writeString(target, 'data'), throwsA(isA<PlatformException>()));
    await expectLater(AtomicFileWriter.writeString(target, 'data'), throwsA(isA<StorageOperationException>()));
  });

  test('concurrent writes to different targets in one directory all survive', () async {
    final targets = List.generate(8, (index) => File('${root.path}/item_$index.json'));

    await Future.wait([
      for (final (index, target) in targets.indexed) AtomicFileWriter.writeString(target, 'value-$index'),
    ]);

    // The temp name is now derived from the pid, a per-process counter and the
    // target name, so concurrent writes cannot claim one temp file. Before that,
    // this case failed outright: two writes started in the same microsecond shared
    // a temp path and the loser's rename threw.
    for (final (index, target) in targets.indexed) {
      expect(target.readAsStringSync(), 'value-$index');
    }
    expect(strayTempFiles(), isEmpty);
  });
}
