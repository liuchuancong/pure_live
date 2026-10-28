import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/music.dart';

audio.MusicTrack _track(String id, {String? title, String artist = '', Duration? duration}) =>
    audio.MusicTrack(id: id, sourceId: 'test', title: title ?? id, artist: artist, duration: duration);

void main() {
  late ProviderContainer container;
  late MusicPlaylistsController controller;

  setUp(() async {
    await StoragePrefs.initSeeded({});
    container = ProviderContainer();
    controller = container.read(musicPlaylistsProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('a list keeps one copy of each song and adds fresh ones in order', () async {
    final playlist = await controller.create('通勤');
    expect(playlist, isNotNull);

    final added = await controller.addTracks(playlist!.id, [
      _track('a', title: 'B 歌'),
      _track('b', title: 'A 歌'),
      _track('a', title: 'B 歌'),
    ]);

    expect(added, 2);
    expect(controller.find(playlist.id)!.tracks.map((track) => track.id), ['a', 'b']);
    expect(await controller.addTrack(playlist.id, _track('a')), isFalse);
  });

  test('sorting re-orders by title, artist and duration', () async {
    final playlist = (await controller.create('排序'))!;
    await controller.addTracks(playlist.id, [
      _track('c', title: 'C', artist: '乙', duration: const Duration(seconds: 30)),
      _track('a', title: 'A', artist: '甲', duration: const Duration(seconds: 10)),
      _track('b', title: 'B', artist: '甲'),
    ]);

    await controller.sortTracks(playlist.id, MusicPlaylistSort.title);
    expect(controller.find(playlist.id)!.tracks.map((track) => track.id), ['a', 'b', 'c']);

    // 乙 sorts before 甲 by code point, so the lone 乙 song leads.
    await controller.sortTracks(playlist.id, MusicPlaylistSort.artist);
    expect(controller.find(playlist.id)!.tracks.map((track) => track.id), ['c', 'a', 'b']);

    // Songs with no duration go last, not first.
    await controller.sortTracks(playlist.id, MusicPlaylistSort.duration);
    expect(controller.find(playlist.id)!.tracks.map((track) => track.id), ['a', 'c', 'b']);
  });

  test('removing a batch keeps the rest', () async {
    final playlist = (await controller.create('移除'))!;
    await controller.addTracks(playlist.id, [_track('a'), _track('b'), _track('c')]);

    await controller.removeTracks(playlist.id, [_track('a'), _track('c')]);

    expect(controller.find(playlist.id)!.tracks.map((track) => track.id), ['b']);
  });

  test('a playlist survives an export and comes back as a new list', () async {
    final playlist = (await controller.create('周末'))!;
    await controller.addTracks(playlist.id, [
      _track('a', title: 'A 歌', artist: '甲', duration: const Duration(seconds: 61)),
      _track('b', title: 'B 歌', artist: '乙'),
    ]);
    final directory = await Directory.systemTemp.createTemp('music_playlist_test');
    addTearDown(() => directory.delete(recursive: true));

    final path = await controller.exportToDirectory(controller.find(playlist.id)!, directory.path);
    expect(File(path).existsSync(), isTrue);

    final imported = await controller.importFromFile(path);
    expect(imported, isNotNull);
    // The existing list keeps its name; the import gets a suffix.
    expect(imported!.name, '周末 (2)');
    expect(imported.tracks.map((track) => track.id), ['a', 'b']);
    expect(imported.tracks.first.duration, const Duration(seconds: 61));
  });

  test('a file that is not a playlist is refused', () async {
    final directory = await Directory.systemTemp.createTemp('music_playlist_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/broken.json')..writeAsStringSync('{"name": 3, "tracks": "nope"}');

    expect(await controller.importFromFile(file.path), isNull);
    expect(controller.state, isEmpty);
  });
}
