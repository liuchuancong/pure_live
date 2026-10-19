import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_library/live_library.dart' show FollowGroup, FollowRepository, InMemoryLibraryStore, LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomRef, RoomContent;
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/features/backup/backup_documents.dart';

LiveRoom _room(String id) => LiveRoom(ref: LiveRoomRef(platform: 'douyu', roomId: id), content: RoomContent(title: id));

LibraryRoom _record(String id) => LibraryRoom(room: _room(id), followedAt: DateTime(2026, 10, 19));

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('backup_documents'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('a follows document round-trips the rooms and the groups', () {
    final repository = FollowRepository(InMemoryLibraryStore());
    // The file's own path: the document goes through the string encoder,
    // which reaches the nested models' toJson, and comes back pure JSON.
    final document = jsonDecode(
      jsonEncode(
        FollowsBackup(
          rooms: [_record('1'), _record('2')],
          groups: [const FollowGroup(id: 'g1', name: '游戏')],
        ).toJson(),
      ),
    ) as Map<String, Object?>;
    final parsed = FollowsBackup.tryParse(document);
    expect(parsed!.rooms.map((room) => room.room.content.title), ['1', '2']);
    expect(parsed.groups.single.name, '游戏');
    expect(repository.rooms, isEmpty); // the document does not touch the store
  });

  test('a file written and read back parses; a foreign document is refused', () {
    final file = writeFollowsBackup(
      folder: folder,
      document: FollowsBackup(rooms: [_record('9')], groups: const []).toJson(),
      now: DateTime(2026, 10, 19, 8, 9, 10),
    );
    expect(file.path, contains('pure_live-follows-20261019-080910.json'));
    final parsed = FollowsBackup.tryParse(readBackupDocument(file));
    expect(parsed!.rooms.single.room.content.title, '9');

    final foreign = File('${folder.path}/other.json')..writeAsStringSync('{"kind": "settings"}');
    expect(FollowsBackup.tryParse(readBackupDocument(foreign)), isNull);
    final broken = File('${folder.path}/broken.json')..writeAsStringSync('not json');
    expect(() => readBackupDocument(broken), throwsFormatException);
  });

  test('restoring a follows document replaces the repository in one step', () async {
    final repository = FollowRepository(InMemoryLibraryStore());
    await repository.load();
    await repository.follow(_room('a'));
    final backup = FollowsBackup.tryParse(jsonDecode(jsonEncode(buildFollowsDocument(repository)))
        as Map<String, Object?>)!;
    final restored = FollowRepository(InMemoryLibraryStore());
    await restored.load();
    await restored.follow(_room('b'));
    await restored.replaceAll(rooms: backup.rooms, groups: backup.groups);
    expect(restored.rooms.map((room) => room.room.content.title), ['a']);
  });

  test('the file list takes both kinds and stamps the follows flag', () {
    File('${folder.path}/pure_live-backup-20261019-080910.zip').writeAsBytesSync([1, 2, 3]);
    writeFollowsBackup(folder: folder, document: const FollowsBackup(rooms: [], groups: []).toJson());
    final entries = listBackups(folder);
    expect(entries.length, 2);
    expect(entries.any((entry) => entry.followsOnly), isTrue);
    expect(entries.any((entry) => !entry.followsOnly), isTrue);
  });

  test('formatBackupSize reads in the units the row line uses', () {
    expect(formatBackupSize(512), '512 B');
    expect(formatBackupSize(2048), '2.0 KB');
    expect(formatBackupSize(3 * 1024 * 1024), '3.0 MB');
  });
}
