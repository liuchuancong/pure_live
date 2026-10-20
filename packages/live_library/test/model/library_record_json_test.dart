import 'dart:convert';

import 'package:live_library/live_library.dart';
import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

/// The document a record writes must be plain JSON data all the way down.
///
/// `jsonEncode` calls a stray object's `toJson()` at encode time, so encoding
/// proves nothing — the live_storage seam hands the map to Hive, which has no
/// adapter for a `LiveRoom` and fails the write with `Cannot write, unknown
/// type` (and the read with a `Map` cast).
void _expectJsonSafe(Object? value, {required String path}) {
  if (value == null || value is String || value is int || value is double || value is bool) {
    return;
  }
  if (value is List<Object?>) {
    for (final (index, item) in value.indexed) {
      _expectJsonSafe(item, path: '$path[$index]');
    }
    return;
  }
  if (value is Map<Object?, Object?>) {
    for (final entry in value.entries) {
      expect(entry.key, isA<String>(), reason: 'key at $path');
      _expectJsonSafe(entry.value, path: '$path.${entry.key}');
    }
    return;
  }
  fail('$path holds a ${value.runtimeType}, which is not JSON data');
}

LiveRoom _room() => LiveRoom.normalized(
  platform: 'douyu',
  roomId: '36252',
  content: const RoomContent(title: '房间标题', coverUrl: 'https://cover/1.jpg'),
  audience: const RoomAudience(popularity: 5303533),
  anchor: const LiveAnchor(platform: 'douyu', anchorId: '36252', name: 'MrGemini'),
);

void main() {
  group('persisted document is JSON data', () {
    test('a watch record nests the room as JSON', () {
      final json = WatchRecord(room: _room(), watchedAt: DateTime.utc(2026, 10, 20)).toJson();
      _expectJsonSafe(json, path: 'WatchRecord');
    });

    test('a followed room record nests the room as JSON', () {
      final json = LibraryRoom(room: _room(), followedAt: DateTime.utc(2026, 10, 20), note: '备注').toJson();
      _expectJsonSafe(json, path: 'LibraryRoom');
    });

    test('a group is JSON safe too', () {
      _expectJsonSafe(
        const FollowGroup(id: 'g1', name: '分组').toJson(),
        path: 'FollowGroup',
      );
    });
  });

  group('round trip', () {
    test('a watch record survives encode/decode', () {
      final record = WatchRecord(
        room: _room(),
        watchedAt: DateTime.utc(2026, 10, 20, 12),
        seq: 3,
        progress: 0.4,
        position: const Duration(minutes: 7),
      );
      final restored = WatchRecord.fromJson(jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>);
      expect(restored, record);
      expect(restored.room.content.title, '房间标题');
      expect(restored.room.audience.popularity, 5303533);
    });

    test('a followed room keeps the user metadata and the snapshot', () {
      final followed = LibraryRoom(
        room: _room(),
        followedAt: DateTime.utc(2026, 10, 1, 9),
        position: 2,
        note: '常看',
        groupIds: const ['g1', 'g2'],
      );
      final restored = LibraryRoom.fromJson(jsonDecode(jsonEncode(followed.toJson())) as Map<String, Object?>);
      expect(restored, followed);
    });
  });
}
