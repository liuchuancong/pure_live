// Module: test/favorites_test.dart
// Purpose: Verify favourites survive their source, keep the user's ordering, and refuse to delete data.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/favorites.md (键 = ContentRef、快照随条目存储、分组、手动 + 按时间、源失效仍可见).
import 'dart:io';

import 'package:pure_live_favorites/pure_live_favorites.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

ContentRef _ref(String sourceId, String contentId, {ContentKind kind = ContentKind.vod}) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: kind);

ContentSummary _summary(String sourceId, String contentId, {String? title, String? cover}) =>
    ContentSummary(ref: _ref(sourceId, contentId), title: title ?? '$sourceId/$contentId', cover: cover);

void main() {
  late MemoryKeyValueStore store;
  late FavoritesService favorites;

  Future<FavoritesService> service({DateTime Function()? clock}) async {
    final built = FavoritesService(repository: KeyValueFavoriteRepository(store), clock: clock ?? () => _t0);
    await built.initialize();
    return built;
  }

  setUp(() async {
    store = MemoryKeyValueStore();
    favorites = await service();
  });

  group('test_favorites_snapshot', () {
    test('test_list_rendersFromTheStoredSnapshotWithNoSourceAnywhere', () async {
      await favorites.add(_ref('a', '1'), _summary('a', '1', title: '标题', cover: 'https://cdn/a.jpg'));

      // The repository holds only what was stored; nothing in this layer can reach a source even if it wanted
      // to, which is the mechanical reading of "源失效仍可见".
      final entry = (await favorites.list()).single;

      expect(entry.snapshot.title, '标题');
      expect(entry.snapshot.cover, 'https://cdn/a.jpg');
      expect(entry.ref.sourceId, 'a');
    });

    test('test_add_existing_ref_refreshesSnapshotButKeepsAddedAt', () async {
      final old = FavoritesService(repository: KeyValueFavoriteRepository(store), clock: () => _t0);
      await old.initialize();
      await old.add(_ref('a', '1'), _summary('a', '1', title: '旧标题'));

      final later = DateTime.utc(2026, 10, 19);
      final renewed = FavoritesService(repository: KeyValueFavoriteRepository(store), clock: () => later);
      await renewed.initialize();
      final entry = await renewed.add(_ref('a', '1'), _summary('a', '1', title: '新标题'));

      expect(entry.snapshot.title, '新标题');
      // Re-opening a favourite is not re-adding it: the age is the user's history, and rewriting it would
      // re-sort the list under them.
      expect(entry.addedAt, _t0);
      expect(await favorites.list(), hasLength(1));
    });

    test('test_sameContentIdOnTwoSources_isTwoFavourites', () async {
      await favorites.add(_ref('a', '1'), _summary('a', '1'));
      await favorites.add(_ref('b', '1'), _summary('b', '1'));

      expect(await favorites.list(), hasLength(2));
    });

    test('test_remove_forgetsOnlyThatRef', () async {
      await favorites.add(_ref('a', '1'), _summary('a', '1'));
      await favorites.add(_ref('a', '2'), _summary('a', '2'));

      await favorites.remove(_ref('a', '1'));

      expect((await favorites.list()).map((entry) => entry.ref.contentId), <String>['2']);
    });

    test('test_remove_notFavorite_reportsItRatherThanQuietlySucceeding', () async {
      await expectLater(
        favorites.remove(_ref('a', 'gone')),
        throwsA(isA<FavoriteException>().having((e) => e.kind, 'kind', FavoriteFailure.notFavorite)),
      );
    });
  });

  group('test_favorites_folders', () {
    test('test_initialize_createsTheDefaultFolderSoAFirstAddWorks', () async {
      final empty = FavoritesService(repository: KeyValueFavoriteRepository(MemoryKeyValueStore()));
      await empty.initialize();

      expect((await empty.folders()).map((folder) => folder.id), <String>[defaultFolderId]);
      await empty.add(_ref('a', '1'), _summary('a', '1'));
      expect(await empty.list(folderId: defaultFolderId), hasLength(1));
    });

    test('test_add_intoAnUnknownFolder_isRefusedAndStoresNothing', () async {
      await expectLater(
        favorites.add(_ref('a', '1'), _summary('a', '1'), folderId: 'nope'),
        throwsA(isA<FavoriteException>().having((e) => e.kind, 'kind', FavoriteFailure.folderNotFound)),
      );

      expect(await favorites.list(), isEmpty);
    });

    test('test_move_betweenFolders_carriesTheSnapshotAndAddedAt', () async {
      final entry = await favorites.add(_ref('a', '1'), _summary('a', '1', title: 'T'));
      await favorites.createFolder('live', '直播');

      final moved = await favorites.move(_ref('a', '1'), 'live');

      expect(moved.folderId, 'live');
      expect(moved.snapshot.title, 'T');
      expect(moved.addedAt, entry.addedAt);
      expect(await favorites.list(folderId: defaultFolderId), isEmpty);
      expect(await favorites.list(folderId: 'live'), hasLength(1));
    });

    test('test_removeFolder_withEntries_isRefusedAndKeepsThem', () async {
      await favorites.createFolder('live', '直播');
      await favorites.add(_ref('a', '1'), _summary('a', '1'), folderId: 'live');

      await expectLater(
        favorites.removeFolder('live'),
        throwsA(isA<FavoriteException>().having((e) => e.kind, 'kind', FavoriteFailure.folderNotEmpty)),
      );

      expect(await favorites.list(folderId: 'live'), hasLength(1));
    });

    test('test_removeFolder_empty_removesIt', () async {
      await favorites.createFolder('temp', '临时');

      await favorites.removeFolder('temp');

      expect((await favorites.folders()).map((folder) => folder.id), isNot(contains('temp')));
    });

    test('test_folders_orderByManualSortKey', () async {
      await favorites.createFolder('c', '第三', sortKey: 30);
      await favorites.createFolder('a', '第一', sortKey: 10);
      await favorites.createFolder('b', '第二', sortKey: 20);

      expect((await favorites.folders()).map((folder) => folder.id), <String>[defaultFolderId, 'a', 'b', 'c']);
    });

    test('test_renameFolder_doesNotTouchItsEntries', () async {
      await favorites.createFolder('live', '直播');
      await favorites.add(_ref('a', '1'), _summary('a', '1'), folderId: 'live');

      await favorites.renameFolder('live', '正在直播');

      final folder = (await favorites.folders()).firstWhere((f) => f.id == 'live');
      expect(folder.name, '正在直播');
      expect((await favorites.list(folderId: 'live')).single.folderId, 'live');
    });
  });

  group('test_favorites_listing', () {
    test('test_list_isNewestFirst', () async {
      final early = FavoritesService(repository: KeyValueFavoriteRepository(store), clock: () => _t0);
      await early.initialize();
      await early.add(_ref('a', 'old'), _summary('a', 'old'));

      final late = FavoritesService(
        repository: KeyValueFavoriteRepository(store),
        clock: () => _t0.add(const Duration(days: 3)),
      );
      await late.initialize();
      await late.add(_ref('a', 'new'), _summary('a', 'new'));

      expect((await late.list()).map((entry) => entry.ref.contentId), <String>['new', 'old']);
    });

    test('test_list_filtersBySourceAndKind', () async {
      await favorites.add(_ref('a', '1'), _summary('a', '1'));
      await favorites.add(_ref('b', '2'), _summary('b', '2'));
      await favorites.add(_ref('a', '3', kind: ContentKind.liveChannel), _summary('a', '3'));

      expect(await favorites.list(sourceId: 'a'), hasLength(2));
      expect(await favorites.list(kind: ContentKind.liveChannel), hasLength(1));
      expect(await favorites.list(sourceId: 'b', kind: ContentKind.vod), hasLength(1));
    });
  });

  group('test_favorites_durability', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('favorites_store');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('test_entries_surviveAStoreReopen', () async {
      final path = '${dir.path}${Platform.pathSeparator}favorites.json';
      final first = FavoritesService(repository: KeyValueFavoriteRepository(FileKeyValueStore(filePath: path)));
      await first.initialize();
      await first.createFolder('live', '直播', sortKey: 5);
      await first.add(_ref('a', '1'), _summary('a', '1', title: 'T'), folderId: 'live');

      final reopened = FavoritesService(repository: KeyValueFavoriteRepository(FileKeyValueStore(filePath: path)));

      expect((await reopened.folders()).map((folder) => folder.id), <String>[defaultFolderId, 'live']);
      final entry = (await reopened.list(folderId: 'live')).single;
      expect(entry.snapshot.title, 'T');
    });

    test('test_aDocumentThatIsNotAList_isRefusedRatherThanReadAsEmpty', () async {
      // Reading it as empty would be the lossy option: the next add rewrites the whole document from what it
      // just read, so every other favourite would go with it.
      final broken = MemoryKeyValueStore();
      await broken.write('favorites.entries', 'not a list');
      final repository = KeyValueFavoriteRepository(broken);

      await expectLater(repository.entries(), throwsA(isA<FormatException>()));
    });
  });
}
