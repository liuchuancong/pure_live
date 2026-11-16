// The vod station's own memory: the search words the page keeps, the
// seasons' continue checkpoints and the archive history's batch removal —
// each one a preference write the store must answer, and each parse a
// malformed record must not break.

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/vod/controller/vod_controller.dart'
    show VodSearchHistoryController, kVodSearchHistoryKey, kVodSearchHistoryLimit, vodSearchHistoryProvider;
import 'package:pure_live/modules/vod/controller/vod_library.dart';

/// A fresh seeded store and the container over it, torn down with the test.
Future<ProviderContainer> _container([Map<String, Object?> seed = const {}]) async {
  await StoragePrefs.initSeeded(seed);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('search history', () {
    test('record puts the newest word first and drops an older copy', () async {
      final container = await _container();
      VodSearchHistoryController controller() => container.read(vodSearchHistoryProvider.notifier);
      await controller().record('综艺');
      await controller().record('纪录片');
      await controller().record('综艺');
      expect(container.read(vodSearchHistoryProvider), ['综艺', '纪录片']);
    });

    test('a blank word and the front word repeated record nothing', () async {
      final container = await _container();
      VodSearchHistoryController controller() => container.read(vodSearchHistoryProvider.notifier);
      await controller().record('动画');
      await controller().record('   ');
      await controller().record('动画');
      expect(container.read(vodSearchHistoryProvider), ['动画']);
      expect(StoragePrefs.getString(kVodSearchHistoryKey), jsonEncode(['动画']));
    });

    test('the list stops at the limit, oldest first out', () async {
      final container = await _container();
      VodSearchHistoryController controller() => container.read(vodSearchHistoryProvider.notifier);
      for (var i = 0; i < kVodSearchHistoryLimit + 3; i++) {
        await controller().record('词$i');
      }
      final history = container.read(vodSearchHistoryProvider);
      expect(history.length, kVodSearchHistoryLimit);
      expect(history.first, '词${kVodSearchHistoryLimit + 2}');
      expect(history.last, '词3');
    });

    test('remove forgets one word, clear forgets every word', () async {
      final container = await _container();
      VodSearchHistoryController controller() => container.read(vodSearchHistoryProvider.notifier);
      await controller().record('甲');
      await controller().record('乙');
      await controller().remove('甲');
      expect(container.read(vodSearchHistoryProvider), ['乙']);
      await controller().clear();
      expect(container.read(vodSearchHistoryProvider), isEmpty);
      expect(StoragePrefs.getString(kVodSearchHistoryKey), jsonEncode(<String>[]));
    });
  });

  group('season checkpoints', () {
    test('save writes the json the reader parses back', () async {
      final container = await _container();
      await container
          .read(vodSeasonProgressProvider.notifier)
          .save(seasonId: '42', title: 'series', cover: 'https://example.com/cover.jpg', episodeIndex: 2, total: 12);
      final raw = StoragePrefs.getString('${kVodSeasonProgressPrefix}42');
      expect(raw, isNotNull);
      final json = jsonDecode(raw!) as Map<String, Object?>;
      expect(json['title'], 'series');
      expect(json['cover'], 'https://example.com/cover.jpg');
      expect(json['episodeIndex'], 2);
      expect(json['total'], 12);
      expect(json['updatedAt'], isA<int>());
    });

    test('checkpoints parse from the store newest first, and a blank one is skipped', () async {
      final container = await _container({
        '${kVodSeasonProgressPrefix}7': jsonEncode({'title': '老档', 'episodeIndex': 3, 'total': 12, 'updatedAt': 1000}),
        '${kVodSeasonProgressPrefix}8': jsonEncode({
          'title': '新档',
          'cover': 'https://example.com/x.jpg',
          'episodeIndex': 5,
          'updatedAt': 2000,
        }),
        '${kVodSeasonProgressPrefix}9': 'not json at all',
        'vod.other': 'not a checkpoint',
      });
      final entries = container.read(vodSeasonProgressProvider);
      expect(entries.map((entry) => entry.seasonId), ['8', '7']);
      expect(entries.first.title, '新档');
      expect(entries.first.cover, 'https://example.com/x.jpg');
      expect(entries.first.total, isNull);
      expect(entries.first.episodeIndex, 5);
      expect(entries.last.total, 12);
    });

    test('completed is the last episode of the ladder', () {
      final stamp = DateTime.fromMillisecondsSinceEpoch(1000);
      final middle = VodSeasonProgress(seasonId: '1', title: 'x', episodeIndex: 5, total: 12, updatedAt: stamp);
      final last = VodSeasonProgress(seasonId: '1', title: 'x', episodeIndex: 11, total: 12, updatedAt: stamp);
      final unknown = VodSeasonProgress(seasonId: '1', title: 'x', episodeIndex: 11, updatedAt: stamp);
      expect(middle.completed, isFalse);
      expect(last.completed, isTrue);
      // A ladder of unknown length never reads as finished.
      expect(unknown.completed, isFalse);
    });

    test('remove drops the checkpoint', () async {
      final container = await _container({
        '${kVodSeasonProgressPrefix}7': jsonEncode({'title': 'x', 'episodeIndex': 0, 'updatedAt': 1}),
      });
      await container.read(vodSeasonProgressProvider.notifier).remove('7');
      expect(StoragePrefs.getString('${kVodSeasonProgressPrefix}7'), isNull);
    });
  });

  group('archive history batch removal', () {
    test('removeMany drops the selected records and keeps the rest', () async {
      final container = await _container({
        '${kVodProgressPrefix}a': jsonEncode({'title': '甲', 'seconds': 10.0, 'completed': false, 'updatedAt': 1000}),
        '${kVodProgressPrefix}b': jsonEncode({'title': '乙', 'seconds': 20.0, 'completed': true, 'updatedAt': 2000}),
        '${kVodProgressPrefix}c': jsonEncode({'title': '丙', 'seconds': 30.0, 'completed': false, 'updatedAt': 3000}),
      });
      final controller = container.read(vodHistoryProvider.notifier);
      expect(container.read(vodHistoryProvider).map((entry) => entry.bvid), ['c', 'b', 'a']);
      await controller.removeMany(['a', 'b']);
      expect(StoragePrefs.getString('${kVodProgressPrefix}a'), isNull);
      expect(StoragePrefs.getString('${kVodProgressPrefix}b'), isNull);
      expect(StoragePrefs.getString('${kVodProgressPrefix}c'), isNotNull);
    });

    test('clear drops every record', () async {
      final container = await _container({
        '${kVodProgressPrefix}a': jsonEncode({'title': '甲', 'seconds': 10.0, 'completed': false, 'updatedAt': 1000}),
        '${kVodProgressPrefix}b': jsonEncode({'title': '乙', 'seconds': 20.0, 'completed': true, 'updatedAt': 2000}),
      });
      final controller = container.read(vodHistoryProvider.notifier);
      await controller.clear();
      expect(StoragePrefs.getString('${kVodProgressPrefix}a'), isNull);
      expect(StoragePrefs.getString('${kVodProgressPrefix}b'), isNull);
    });
  });
}
