import 'dart:convert' show jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart';

void main() {
  group('the shelf badge', () {
    test('totals the episodes each favorite gained, never below zero', () {
      const state = HongguoLibraryState(
        updates: {
          'a': HongguoFavoriteUpdate(total: 30, seen: 24, checkedAt: 1),
          'b': HongguoFavoriteUpdate(total: 12, seen: 12, checkedAt: 1),
          // A stored count that shrank (the platform pulled episodes).
          'c': HongguoFavoriteUpdate(total: 8, seen: 10, checkedAt: 1),
        },
      );

      expect(state.addedCount, 6);
      expect(const HongguoLibraryState().addedCount, 0);
    });

    test('drops the series it opens and keeps the others', () async {
      await StoragePrefs.initSeeded({
        'hongguo.library.favoriteUpdates': jsonEncode({
          'a': {'total': 30, 'seen': 24, 'checkedAt': 1},
          'b': {'total': 12, 'seen': 10, 'checkedAt': 1},
        }),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(hongguoLibraryProvider.notifier);

      expect(container.read(hongguoLibraryProvider).addedCount, 8);

      controller.acknowledgeUpdates('a');

      final state = container.read(hongguoLibraryProvider);
      expect(state.addedCount, 2);
      expect(state.updates['a']!.added, 0);
      expect(state.updates['a']!.total, 30);
    });
  });

  group('the favorite card line', () {
    final t = Translations();
    const series = HongguoSeries(seriesId: 'a', title: '剧');

    HongguoWatchProgress progress({bool completed = false}) => HongguoWatchProgress(
      seriesId: 'a',
      title: '剧',
      cover: '',
      episodeIndex: 24,
      episodeVid: 'v',
      positionMs: 1000,
      durationMs: 2000,
      completed: completed,
      updatedAt: 1,
    );

    test('names the total with what it gained and where the viewer stopped', () {
      final library = HongguoLibraryState(
        updates: const {'a': HongguoFavoriteUpdate(total: 30, seen: 24, checkedAt: 1)},
        history: [progress()],
      );

      expect(hongguoFavoriteLine(t, library, series), '共 30 集（+6） · 看到第 24 集');
    });

    test('a checked total with nothing new drops the gain', () {
      const library = HongguoLibraryState(updates: {'a': HongguoFavoriteUpdate(total: 30, seen: 30, checkedAt: 1)});

      expect(hongguoFavoriteLine(t, library, series), '共 30 集');
    });

    test('an unchecked favorite falls back to its own count, then to the pending note', () {
      expect(hongguoFavoriteLine(t, const HongguoLibraryState(), series.copyWith(episodeCount: 12)), '共 12 集');
      expect(hongguoFavoriteLine(t, const HongguoLibraryState(), series), '总集数待更新');
    });
  });
}
