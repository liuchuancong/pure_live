// The file half of "bring a take home", exercised against real temporary
// folders: measuring one, copying one and proving the copy, and reading a
// task's path after the move. This is the code that decides whether a viewer's
// recording may have its source deleted, so the checks are pinned here rather
// than only trusted in the engine.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/modules/live/recorder/engine/recording_take_move.dart';

Directory _temp() {
  final dir = Directory.systemTemp.createTempSync('take_move_test');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void _write(Directory dir, String name, int bytes) {
  final file = File(p.join(dir.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(bytes, 7));
}

void main() {
  test('folderBytes sums the files and skips the app’s own marker', () async {
    final root = _temp();
    _write(root, 'a.mp4', 100);
    _write(root, p.join('original', 'b.ts'), 50);
    _write(root, '.pure_live_recording_root', 999);

    expect(await folderBytes(root), 1149);
    expect(await folderBytes(root, exclude: {'.pure_live_recording_root'}), 150);
  });

  test('a verified copy keeps the nested shape and matches the source', () async {
    final base = _temp();
    final source = Directory(p.join(base.path, '旧目录', 'take_a'))..createSync(recursive: true);
    _write(source, 'take.combined.mp4', 4096);
    _write(source, p.join('original', 'take_000.ts'), 2048);
    _write(source, '弹幕.ass', 128);
    final destination = Directory(p.join(base.path, '当前目录', 'take_a'));

    expect(await copyTakeVerified(source, destination), isTrue);
    expect(File(p.join(destination.path, 'take.combined.mp4')).lengthSync(), 4096);
    expect(File(p.join(destination.path, 'original', 'take_000.ts')).lengthSync(), 2048);
    expect(File(p.join(destination.path, '弹幕.ass')).existsSync(), isTrue);
    expect(await folderBytes(source), await folderBytes(destination));
  });

  test('a copy that does not match the source is refused, and the source stays', () async {
    final base = _temp();
    final source = Directory(p.join(base.path, 'take_b'))..createSync(recursive: true);
    _write(source, 'take.combined.mp4', 1024);
    // The destination already holds another take's bytes: copying on top would
    // leave more content than the source has, which the total check must catch.
    final destination = Directory(p.join(base.path, 'moved', 'take_b'))..createSync(recursive: true);
    _write(destination, 'stranger.mp4', 4096);

    expect(await copyTakeVerified(source, destination), isFalse);
    expect(File(p.join(source.path, 'take.combined.mp4')).lengthSync(), 1024, reason: 'the source is the take');
  });

  test('a cancelled copy reports failure and leaves the source whole', () async {
    final base = _temp();
    final source = Directory(p.join(base.path, 'take_c'))..createSync(recursive: true);
    _write(source, 'a.mp4', 64);
    _write(source, 'b.ts', 64);
    final destination = Directory(p.join(base.path, 'moved', 'take_c'));

    var asked = 0;
    final copied = await copyTakeVerified(source, destination, cancelled: () => ++asked > 0);

    expect(copied, isFalse);
    expect(File(p.join(source.path, 'a.mp4')).lengthSync(), 64);
    expect(File(p.join(source.path, 'b.ts')).lengthSync(), 64);
  });

  test('a row’s path is rebased onto the new home', () {
    const from = r'D:\旧\take_a';
    const to = r'D:\新\take_a';
    expect(rebaseTakePath('', from: from, to: to), to);
    expect(rebaseTakePath(from, from: from, to: to), to);
    expect(rebaseTakePath(r'D:\旧\take_a\take.combined.mp4', from: from, to: to), r'D:\新\take_a\take.combined.mp4');
    // Something the folder never held keeps its name beside the new folder
    // rather than a `..` walk out of it.
    expect(rebaseTakePath(r'D:\别处\stray.mp4', from: from, to: to), r'D:\新\take_a\stray.mp4');
    expect(rebaseTakePath('  $from  ', from: from, to: to), to);
  });
}
