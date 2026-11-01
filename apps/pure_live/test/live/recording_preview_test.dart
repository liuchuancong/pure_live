import 'dart:io' show Directory, File, Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('recording_preview'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  void write(String name, List<int> bytes) => File(at(name)).writeAsBytesSync(bytes);

  test('a stored file plays only when its extension can', () {
    write('joined.mp4', List<int>.filled(16, 0));
    write('notes.txt', List<int>.filled(16, 0));
    expect(playableFileAt(at('joined.mp4')), at('joined.mp4'));
    expect(playableFileAt(at('notes.txt')), isNull);
    expect(playableFileAt(null), isNull);
    expect(playableFileAt('   '), isNull);
    expect(playableFileAt(at('gone.mp4')), isNull);
  });

  test('a take folder plays its finished picture over its segments', () {
    write('take_a.flv', List<int>.filled(4096, 0));
    write('take_a.mp4', List<int>.filled(1024, 0));
    write('room.mp4', List<int>.filled(8192, 0));
    expect(playableFileAt(root.path), at('room.mp4'));
  });

  test('a take the join never ran plays its largest segment', () {
    write('take_a.flv', List<int>.filled(1024, 0));
    write('take_b.flv', List<int>.filled(4096, 0));
    write('take_c.flv', List<int>.filled(16, 0));
    expect(playableFileAt(root.path), at('take_b.flv'));
  });

  test('the archived segments are not the take', () {
    write('room.mp4', List<int>.filled(1024, 0));
    final archive = Directory(at('original'))..createSync();
    File('${archive.path}${Platform.pathSeparator}take_a.mp4').writeAsBytesSync(List<int>.filled(65536, 0));
    expect(playableFileAt(root.path), at('room.mp4'));
  });

  test('an empty or chat-only folder plays nothing', () {
    write('room.ass', List<int>.filled(16, 0));
    write('empty.mp4', const []);
    expect(playableFileAt(root.path), isNull);
  });

  test('an extension in another case still plays', () {
    write('ROOM.MP4', List<int>.filled(16, 0));
    expect(playableFileAt(root.path), at('ROOM.MP4'));
  });
}
