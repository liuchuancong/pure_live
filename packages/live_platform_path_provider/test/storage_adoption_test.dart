import 'dart:io';

import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `StorageAdoption` is the boot-time carrier for a moved data tree, so the
/// cases below pin its promises: every entry moves, a name the target
/// already holds is never overwritten and is reported instead, a missing or
/// identical source has nothing to carry, and an emptied source does not
/// linger.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_adoption');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('every entry moves and the emptied source is removed', () async {
    final from = Directory('${root.path}/old')..createSync();
    File('${from.path}/boxes.hive').writeAsStringSync('data');
    final nested = Directory('${from.path}/covers')..createSync();
    File('${nested.path}/a.jpg').writeAsStringSync('image');
    final to = Directory('${root.path}/new')..createSync();

    final report = await StorageAdoption.carry(from: from, to: to);

    expect(report, isNotNull);
    expect(report!.isComplete, isTrue);
    expect(report.moved, ['boxes.hive', 'covers']);
    expect(report.blocked, isEmpty);
    expect(File('${to.path}/boxes.hive').readAsStringSync(), 'data');
    expect(File('${to.path}/covers/a.jpg').readAsStringSync(), 'image');
    expect(from.existsSync(), isFalse, reason: 'an emptied tree does not linger');
  });

  test('a name the target already holds is never overwritten', () async {
    final from = Directory('${root.path}/old')..createSync();
    File('${from.path}/a.txt').writeAsStringSync('old');
    File('${from.path}/b.txt').writeAsStringSync('portable');
    final to = Directory('${root.path}/new')..createSync();
    File('${to.path}/a.txt').writeAsStringSync('new');

    final report = await StorageAdoption.carry(from: from, to: to);

    expect(report!.moved, ['b.txt']);
    expect(report.blocked, ['a.txt']);
    expect(report.isComplete, isFalse);
    expect(File('${to.path}/a.txt').readAsStringSync(), 'new', reason: 'the target wins, never the carry');
    expect(File('${from.path}/a.txt').readAsStringSync(), 'old', reason: 'the blocked entry stays put');
    expect(from.existsSync(), isTrue, reason: 'a tree with leftovers is not removed');
  });

  test('a missing source has nothing to carry', () async {
    final to = Directory('${root.path}/new')..createSync();

    final report = await StorageAdoption.carry(from: Directory('${root.path}/gone'), to: to);

    expect(report, isNull);
  });

  test('carrying a tree into itself has nothing to do', () async {
    final same = Directory('${root.path}/same')..createSync();
    File('${same.path}/x.txt').writeAsStringSync('kept');

    final report = await StorageAdoption.carry(from: same, to: same);

    expect(report, isNull);
    expect(File('${same.path}/x.txt').readAsStringSync(), 'kept');
  });

  test('an empty source is tidied away and reports an empty carry', () async {
    final from = Directory('${root.path}/old')..createSync();
    final to = Directory('${root.path}/new')..createSync();

    final report = await StorageAdoption.carry(from: from, to: to);

    expect(report, isNotNull);
    expect(report!.moved, isEmpty);
    expect(report.blocked, isEmpty);
    expect(from.existsSync(), isFalse);
  });
}
