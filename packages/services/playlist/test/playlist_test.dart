// Module: test/playlist_test.dart
// Purpose: Verify a playlist keeps the order the user made, including the rows that repeat.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/content/playlist.md (顺序即语义、跨源混排、快照随条目、与 PlaybackQueue 分界).
import 'dart:io';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_playlist/pure_live_playlist.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId, {ContentKind kind = ContentKind.vod}) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: kind);

PlaylistItem _item(String sourceId, String contentId, {String? title}) => PlaylistItem(
  ref: _ref(sourceId, contentId),
  snapshot: ContentSummary(ref: _ref(sourceId, contentId), title: title ?? '$sourceId/$contentId'),
);

void main() {
  late MemoryKeyValueStore store;
  late PlaylistsService playlists;

  setUp(() async {
    store = MemoryKeyValueStore();
    playlists = PlaylistsService(repository: KeyValuePlaylistRepository(store));
    await playlists.create('mine', '我的歌单');
  });

  group('test_playlist_order', () {
    test('test_addItem_appendsAndKeepsInsertionOrder', () async {
      await playlists.addItem('mine', _item('a', '1'));
      await playlists.addItem('mine', _item('a', '2'));

      final list = await playlists.get('mine');

      expect(list.items.map((item) => item.ref.contentId), <String>['1', '2']);
    });

    test('test_addItem_atIndex_insertsBeforeThatRow', () async {
      await playlists.addItem('mine', _item('a', '1'));
      await playlists.addItem('mine', _item('a', '3'));

      final updated = await playlists.addItem('mine', _item('a', '2'), index: 1);

      expect(updated.items.map((item) => item.ref.contentId), <String>['1', '2', '3']);
    });

    test('test_sameContentTwice_staysTwoRows', () async {
      // A queue the user ordered may list one item twice (an M3U does); identity is the index, not the ref,
      // so nothing here may collapse the pair the way a favourites set would.
      await playlists.addItem('mine', _item('a', '1'));
      await playlists.addItem('mine', _item('a', '1'));

      final list = await playlists.get('mine');

      expect(list.items, hasLength(2));
      expect(await playlists.indexOfFirst('mine', _ref('a', '1')), 0);

      final removed = await playlists.removeItem('mine', 0);
      expect(removed.items, hasLength(1));
    });

    test('test_moveItem_reorders', () async {
      for (final id in <String>['1', '2', '3']) {
        await playlists.addItem('mine', _item('a', id));
      }

      final moved = await playlists.moveItem('mine', 2, 0);

      expect(moved.items.map((item) => item.ref.contentId), <String>['3', '1', '2']);
    });

    test('test_moveItem_toTheEnd_isAllowed', () async {
      for (final id in <String>['1', '2']) {
        await playlists.addItem('mine', _item('a', id));
      }

      final moved = await playlists.moveItem('mine', 0, 2);

      expect(moved.items.map((item) => item.ref.contentId), <String>['2', '1']);
    });

    test('test_outOfRangeIndex_isRefusedAndChangesNothing', () async {
      await playlists.addItem('mine', _item('a', '1'));

      await expectLater(
        playlists.removeItem('mine', 5),
        throwsA(isA<PlaylistException>().having((e) => e.kind, 'kind', PlaylistFailure.indexOutOfRange)),
      );
      expect((await playlists.get('mine')).items, hasLength(1));
    });

    test('test_indexOnAnEmptyList_isRefused', () async {
      await expectLater(
        playlists.removeItem('mine', 0),
        throwsA(isA<PlaylistException>().having((e) => e.kind, 'kind', PlaylistFailure.indexOutOfRange)),
      );
    });
  });

  group('test_playlist_items', () {
    test('test_list_rendersFromSnapshotsOnly', () async {
      await playlists.addItem('mine', _item('a', '1', title: '歌一'));
      await playlists.addItem('mine', _item('music', '9', title: '歌二'));

      final list = await playlists.get('mine');

      // 跨源混排:B 站与音乐在同一条队列里,各自的源不在场也照样列得出来。
      expect(list.items.map((item) => item.snapshot.title), <String>['歌一', '歌二']);
      expect(list.items.map((item) => item.ref.sourceId), <String>['a', 'music']);
    });

    test('test_clear_emptiesTheListButKeepsIt', () async {
      await playlists.addItem('mine', _item('a', '1'));

      final cleared = await playlists.clear('mine');

      expect(cleared.items, isEmpty);
      expect(cleared.title, '我的歌单');
      expect((await playlists.list()).map((playlist) => playlist.id), <String>['mine']);
    });

    test('test_delete_removesTheWholePlaylist', () async {
      await playlists.delete('mine');

      expect(await playlists.list(), isEmpty);
      await expectLater(
        playlists.get('mine'),
        throwsA(isA<PlaylistException>().having((e) => e.kind, 'kind', PlaylistFailure.notFound)),
      );
    });
  });

  group('test_playlist_bookkeeping', () {
    test('test_create_withAnExistingId_isRefused', () async {
      await expectLater(
        playlists.create('mine', '又一个'),
        throwsA(isA<PlaylistException>().having((e) => e.kind, 'kind', PlaylistFailure.duplicateId)),
      );
    });

    test('test_rename_and_setPlayMode_stick', () async {
      final renamed = await playlists.rename('mine', '改名后的');
      final shuffled = await playlists.setPlayMode('mine', PlaylistPlayMode.shuffle);

      expect(renamed.title, '改名后的');
      expect(shuffled.id, 'mine');
      expect(shuffled.playMode, PlaylistPlayMode.shuffle);
      // A policy is stored, not obeyed: the next row is the playback queue's decision, not this list's.
      expect(shuffled.items, isEmpty);
    });

    test('test_emptyPlaylist_isStillAPlaylist', () async {
      // A user creates a list before filling it; refusing the empty one would lose the thing they just made.
      final created = await playlists.create('empty', '空歌单');

      expect(created.isEmpty, isTrue);
      expect(await playlists.list(), hasLength(2));
    });
  });

  group('test_playlist_durability', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('playlist_store');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('test_playlists_surviveAStoreReopen', () async {
      final path = '${dir.path}${Platform.pathSeparator}playlists.json';
      final first = PlaylistsService(repository: KeyValuePlaylistRepository(FileKeyValueStore(filePath: path)));
      await first.create('mine', '我的歌单');
      await first.addItem('mine', _item('a', '1', title: '歌一'));
      await first.setPlayMode('mine', PlaylistPlayMode.singleLoop);

      final reopened = PlaylistsService(repository: KeyValuePlaylistRepository(FileKeyValueStore(filePath: path)));
      final list = await reopened.get('mine');

      expect(list.title, '我的歌单');
      expect(list.playMode, PlaylistPlayMode.singleLoop);
      expect(list.items.single.snapshot.title, '歌一');
    });

    test('test_aDocumentThatIsNotAList_isRefusedRatherThanReadAsEmpty', () async {
      final broken = MemoryKeyValueStore();
      await broken.write('playlists', 'not a list');

      await expectLater(KeyValuePlaylistRepository(broken).all(), throwsA(isA<FormatException>()));
    });

    test('test_jsonRoundTrip_keepsOrderAndPolicy', () async {
      final playlist = Playlist(
        id: 'p',
        title: 'P',
        items: <PlaylistItem>[_item('a', '1'), _item('b', '2')],
        playMode: PlaylistPlayMode.shuffle,
      );

      final decoded = Playlist.fromJson(playlist.toJson());

      expect(decoded.id, 'p');
      expect(decoded.id, 'p');
      expect(decoded.playMode, PlaylistPlayMode.shuffle);
      expect(decoded.items.map((item) => item.ref.sourceId), <String>['a', 'b']);
    });
  });
}
