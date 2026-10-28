import 'dart:convert' show jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
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
}
