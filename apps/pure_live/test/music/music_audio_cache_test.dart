import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/library/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/music_audio_cache.dart';
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/widgets/music_lyric_panel.dart' show musicLyricTrackKey;

/// The audio cache's own ledger and the comment row helpers: a key that
/// strips what a filename cannot hold, a partial file that only becomes a
/// cached one once it was written whole, a trim that evicts the least
/// recently played first and never the song playing, and the wrapper that
/// answers a hit from disk, re-resolves a hit whose file vanished and
/// quietly copies a network answer into the cache while it plays. The
/// comment helpers read both timestamp units and drop empty rows.
void main() {
  group('the cache keys', () {
    test('a key strips what a filename cannot hold, and a null quality shares the auto slot', () {
      final track = _track(id: '977/A B');
      expect(MusicAudioCacheKey.of(track, audio.MusicQuality.k320), 'kw_977AB_320k');
      expect(MusicAudioCacheKey.of(track, null), 'kw_977AB_auto');
      expect(MusicAudioCacheKey.fileOf('kw_977_auto'), 'kw_977_auto.audio');
      expect(MusicAudioCacheKey.partOf('kw_977_auto'), 'kw_977_auto.audio.part');
    });
  });

  group('the lyric track key', () {
    test('the same id on different platforms is a different lyric request', () {
      final first = musicLyricTrackKey(_track());
      final second = musicLyricTrackKey(_track(sourceId: 'wy'));
      expect(first, 'kw:977');
      expect(second, 'wy:977');
      expect(second, isNot(first));
      expect(musicLyricTrackKey(null), isNull);
    });
  });

  group('the cache ledger', () {
    late _MapFiles files;
    late MusicAudioCache cache;
    var moment = DateTime(2026);

    setUp(() {
      files = _MapFiles();
      moment = DateTime(2026);
      cache = MusicAudioCache(files, maxBytes: 100, now: () => moment);
    });

    test('a load indexes the finished files, deletes the leftovers and ignores the rest', () async {
      files.files.addAll({
        'kw_a_auto.audio': (size: 10, modified: DateTime(2025, 12)),
        'kw_b_auto.audio.part': (size: 5, modified: DateTime(2025, 12, 2)),
        'kw_c.txt': (size: 3, modified: DateTime(2025, 12, 3)),
      });
      await cache.load();
      expect(cache.keys, ['kw_a_auto']); // the finished file joined, its last use its own mtime
      expect(cache.totalBytes, 10);
      expect(files.files.containsKey('kw_b_auto.audio.part'), isFalse); // the leftover partial went
      expect(files.files.containsKey('kw_c.txt'), isTrue); // a stranger's file is nobody's to delete
    });

    test('a begin names the partial once, and a commit renames it whole', () async {
      expect(cache.begin('kw_a_auto'), 'kw_a_auto.audio.part');
      expect(cache.begin('kw_a_auto'), isNull); // already in flight

      await files.delete('kw_a_auto.audio.part'); // the writer never wrote anything
      await cache.commit('kw_a_auto');
      expect(cache.keys, isEmpty); // an empty download is no download

      expect(cache.begin('kw_a_auto'), 'kw_a_auto.audio.part');
      files.files['kw_a_auto.audio.part'] = (size: 40, modified: moment);
      await cache.commit('kw_a_auto');
      expect(files.files.containsKey('kw_a_auto.audio'), isTrue); // the partial became the file
      expect(files.files.containsKey('kw_a_auto.audio.part'), isFalse);
      expect(cache.lookup('kw_a_auto'), 'kw_a_auto.audio'); // and the cache answers it
    });

    test('an abort frees the slot and takes the partial with it', () async {
      expect(cache.begin('kw_a_auto'), isNotNull);
      await cache.abort('kw_a_auto');
      expect(files.files.containsKey('kw_a_auto.audio.part'), isFalse);
      expect(cache.begin('kw_a_auto'), isNotNull); // the slot is free again
    });

    test('a trim evicts the least recently played first and never the song playing', () async {
      cache.maxBytes = 1000; // seed freely, the cap bites afterwards
      moment = DateTime(2026);
      await _seed(cache, files, {'kw_old': 60});
      moment = moment.add(const Duration(minutes: 5));
      await _seed(cache, files, {'kw_mid': 60});
      moment = moment.add(const Duration(minutes: 5));
      cache.lookup('kw_old'); // the old one played again: it jumps ahead of mid
      await _seed(cache, files, {'kw_new': 60});

      cache.maxBytes = 100;
      await cache.trim(keep: {'kw_new'});
      // Three sixty-byte files against a hundred: the least recently
      // played go first and the playing one stays whatever the size says.
      expect(cache.keys, ['kw_new']);
      expect(files.files.containsKey('kw_mid.audio'), isFalse); // the file went with the entry
      expect(files.files.containsKey('kw_old.audio'), isFalse);
    });

    test('a forget drops the entry and keeps the file, and a clear drops both', () async {
      await _seed(cache, files, {'kw_a': 10});
      cache.forget('kw_a');
      expect(cache.lookup('kw_a'), isNull);
      expect(files.files.containsKey('kw_a.audio'), isTrue); // the file stays for the sweep to find

      await _seed(cache, files, {'kw_b': 10});
      expect(cache.begin('kw_c'), isNotNull);
      files.files['kw_c.audio.part'] = (size: 9, modified: moment);
      await cache.clear();
      expect(cache.keys, isEmpty);
      expect(files.files.containsKey('kw_b.audio'), isFalse); // finished files go
      expect(files.files.containsKey('kw_c.audio.part'), isTrue); // a download in flight finishes into it
    });

    test('a hit whose entry is gone re-resolves instead of answering a dead path', () async {
      await _seed(cache, files, {'kw_a': 10});
      files.files.remove('kw_a.audio'); // the viewer or a sweep deleted it
      expect(cache.lookup('kw_a'), 'kw_a.audio'); // the ledger still believes
      cache.forget('kw_a');
      expect(cache.lookup('kw_a'), isNull); // and now it knows
    });
  });

  group('the comment helpers', () {
    test('a row without text never lands', () {
      final rows = commentsOf([
        {'id': '1', 'msg': '好'},
        'junk',
        {'id': '2', 'msg': '  '},
        {'id': '3'}, // no msg at all
      ], (row) => row['msg'] == null ? null : MusicComment.fromJson(row));
      expect(rows, hasLength(1));
      expect(rows.single.text, '好');
    });

    test('a timestamp reads in both units and refuses nothing', () {
      expect(commentTimeOf('1700000000'), DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(commentTimeOf(1700000000000, seconds: false), DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(commentTimeOf('0'), isNull);
      expect(commentTimeOf('-5'), isNull);
      expect(commentTimeOf('junk'), isNull);
      expect(commentTextOf('  '), isNull);
      expect(commentTextOf(' hi '), 'hi');
    });
  });

  group('the wearing source', () {
    late Directory root;
    late _StubHttp http;
    late _StubSource inner;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('music-cache-test');
      http = _StubHttp();
      inner = _StubSource();
    });

    tearDown(() async {
      // A background copy may still hold its partial file open; Windows
      // refuses the delete until the handle closes, so give it a moment.
      for (var i = 0; i < 20; i++) {
        try {
          await root.delete(recursive: true);
          return;
        } on Object {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }
    });

    CachedTrackSource wearing({bool cacheOff = false}) =>
        CachedTrackSource(inner, environment: () => cacheOff ? null : (directory: root, limitMb: 8, http: http));

    Future<Directory> directoryWithAudio(String prefix, Map<String, int> sizes) async {
      final directory = await root.createTemp(prefix);
      final cacheDir = Directory('${directory.path}/music-audio');
      await cacheDir.create(recursive: true);
      for (final entry in sizes.entries) {
        await File('${cacheDir.path}/${entry.key}.audio').writeAsBytes(List.filled(entry.value, 1));
      }
      return directory;
    }

    test('a cache that is off rides straight through', () async {
      final source = audio.TrackSource(uri: Uri.parse('https://cdn.example/x.mp3'));
      inner.answer = source;
      final resolved = await wearing(cacheOff: true).resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(identical(resolved, source), isTrue);
      expect(inner.resolves, 1);
      expect(http.opens, 0); // nothing to download into nowhere
    });

    test('a hit answers a local file without asking the platform', () async {
      final cacheDir = Directory('${root.path}/music-audio');
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/kw_977_128k.audio').writeAsBytes([1, 2, 3]);
      inner.answer = audio.TrackSource(uri: Uri.file('/dev/null'), isLocal: true);

      final hit = await wearing().resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(hit.isLocal, isTrue);
      expect(hit.uri.isScheme('file'), isTrue);
      expect(inner.resolves, 0); // the platform was never asked
    });

    test('a hit whose file vanished re-resolves instead of answering a dead path', () async {
      final cacheDir = Directory('${root.path}/music-audio');
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/kw_977_128k.audio').writeAsBytes([1, 2, 3]);
      final wrapped = wearing();
      await wrapped.resolveTrackSource(_track(), quality: audio.MusicQuality.k128); // warm the ledger

      await File('${cacheDir.path}/kw_977_128k.audio').delete();
      inner.answer = audio.TrackSource(uri: Uri.parse('https://cdn.example/fresh.mp3'));
      final again = await wrapped.resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(again.isLocal, isFalse); // the dead path was not answered
      expect(inner.resolves, 1); // the ledger forgot and the platform answered
    });

    test('a network answer is copied into the cache while it plays', () async {
      final wrapped = wearing();
      http.body = Uint8List.fromList([4, 5, 6, 7]);
      inner.answer = audio.TrackSource(uri: Uri.parse('https://cdn.example/song.mp3'));

      final resolved = await wrapped.resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(resolved.isLocal, isFalse); // the play goes straight to the network
      expect(http.opens, 1); // the copy flies in the background

      // The copy lands on its own; then the same ask answers from the disk.
      await _until(() => File('${root.path}/music-audio/kw_977_128k.audio').existsSync());
      inner.answer = audio.TrackSource(uri: Uri.parse('https://cdn.example/song.mp3'));
      final again = await wearing().resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(again.isLocal, isTrue);
      expect(again.uri.isScheme('file'), isTrue);
    });

    test('a moved cache directory is read instead of the previous root', () async {
      Future<Directory> directoryWithBytes(int size) async {
        final directory = await root.createTemp('cache-move');
        final cacheDir = Directory('${directory.path}/music-audio');
        await cacheDir.create(recursive: true);
        await File('${cacheDir.path}/kw_977_128k.audio').writeAsBytes(List.filled(size, 1));
        return directory;
      }

      final first = await directoryWithBytes(3);
      final second = await directoryWithBytes(7);
      var directory = first;
      final wrapped = CachedTrackSource(inner, environment: () => (directory: directory, limitMb: 8, http: http));
      await wrapped.resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      directory = second;
      final moved = await wrapped.resolveTrackSource(_track(), quality: audio.MusicQuality.k128);
      expect(File.fromUri(moved.uri).readAsBytesSync(), hasLength(7));
      expect(inner.resolves, 0);
    });

    test('registered sources share one usage ledger and one clear', () async {
      final directory = await directoryWithAudio('cache-shared', {'kw_977_auto': 3, 'wy_42_auto': 7});
      final box = MusicAudioCacheBox();
      addTearDown(box.disarm);
      MusicCacheEnvironment? environment() => (directory: directory, limitMb: 8, http: http);
      final first = box.register(inner, environment: environment);
      final second = box.register(inner, environment: environment);

      final firstHit = await first.resolveTrackSource(_track());
      final secondHit = await second.resolveTrackSource(_track(id: '42', sourceId: 'wy'));
      expect(firstHit.isLocal, isTrue);
      expect(secondHit.isLocal, isTrue);
      expect(inner.resolves, 0);
      // Ten bytes, not twenty: both sources resolved the same directory and
      // capacity to one MusicAudioCache rather than loading private indexes.
      expect(await box.usageBytes(), 10);

      await box.clear();
      expect(await box.usageBytes(), 0);
      expect(File('${directory.path}/music-audio/kw_977_auto.audio').existsSync(), isFalse);
      expect(File('${directory.path}/music-audio/wy_42_auto.audio').existsSync(), isFalse);
    });

    test('disarming one window box leaves the other window sources intact', () async {
      final directory = await directoryWithAudio('cache-isolated', {'kw_977_auto': 3});
      final left = ProviderContainer();
      final right = ProviderContainer();
      addTearDown(left.dispose);
      addTearDown(right.dispose);
      MusicCacheEnvironment? environment() => (directory: directory, limitMb: 8, http: http);
      final leftBox = left.read(musicAudioCacheBoxProvider);
      final rightBox = right.read(musicAudioCacheBoxProvider);
      leftBox.register(inner, environment: environment);
      final rightSource = rightBox.register(inner, environment: environment);
      expect(await leftBox.usageBytes(), 3);
      expect(await rightBox.usageBytes(), 3);

      leftBox.disarm();
      expect(await leftBox.usageBytes(), isNull);
      await leftBox.clear();
      expect(await rightBox.usageBytes(), 3);
      expect(File('${directory.path}/music-audio/kw_977_auto.audio').existsSync(), isTrue);
      expect((await rightSource.resolveTrackSource(_track())).isLocal, isTrue);
      expect(inner.resolves, 0);
    });

    test('the settings box follows the active sources and belongs to one window scope', () async {
      Future<CachedTrackSource> sourceWithBytes(int size) async {
        final directory = await root.createTemp('cache-window');
        final cacheDir = Directory('${directory.path}/music-audio');
        await cacheDir.create(recursive: true);
        await File('${cacheDir.path}/kw_977_auto.audio').writeAsBytes(List.filled(size, 1));
        return CachedTrackSource(inner, environment: () => (directory: directory, limitMb: 8, http: http));
      }

      final first = await sourceWithBytes(3);
      final second = await sourceWithBytes(7);
      final left = ProviderContainer();
      final right = ProviderContainer();
      addTearDown(left.dispose);
      addTearDown(right.dispose);
      final leftBox = left.read(musicAudioCacheBoxProvider);
      final rightBox = right.read(musicAudioCacheBoxProvider);

      leftBox.wearing = first;
      expect(await leftBox.usageBytes(), 3);
      leftBox.wearing = second;
      expect(await leftBox.usageBytes(), 7);
      rightBox.wearing = first;
      expect(await rightBox.usageBytes(), 3);

      leftBox.disarm();
      expect(await leftBox.usageBytes(), isNull);
      expect(await rightBox.usageBytes(), 3);
    });
  });
}

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('the awaited condition never came');
}

/// Seeds finished files into the ledger: a begin names the partial, the
/// test writes it, and a commit lands it.
Future<void> _seed(MusicAudioCache cache, _MapFiles files, Map<String, int> sizes) async {
  for (final entry in sizes.entries) {
    expect(cache.begin(entry.key), isNotNull);
    files.files[MusicAudioCacheKey.partOf(entry.key)] = (size: entry.value, modified: DateTime(2026));
    await cache.commit(entry.key);
  }
}

audio.MusicTrack _track({String id = '977', String sourceId = 'kw'}) =>
    audio.MusicTrack(id: id, sourceId: sourceId, title: '晴天', artist: '周杰伦');

/// The files, as a map: no disk, no clock.
final class _MapFiles implements MusicCacheFiles {
  final files = <String, ({int size, DateTime modified})>{};

  @override
  Future<List<CachedAudioFile>> list() async => [
    for (final entry in files.entries) (name: entry.key, size: entry.value.size, modified: entry.value.modified),
  ];

  @override
  Future<int?> sizeOf(String name) async => files[name]?.size;

  @override
  Future<void> rename(String from, String to) async {
    final value = files.remove(from);
    if (value != null) files[to] = value;
  }

  @override
  Future<void> delete(String name) async {
    files.remove(name);
  }
}

/// A platform the wrapper wraps: one canned answer, counted asks.
final class _StubSource extends audio.MusicSource {
  audio.TrackSource? answer;
  int resolves = 0;

  @override
  String get id => 'kw';

  @override
  String get name => 'stub';

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    resolves += 1;
    return answer!;
  }
}

/// The transport the download rides: one canned body per open.
final class _StubHttp implements LiveHttp {
  Uint8List? body;
  int opens = 0;

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    opens += 1;
    return _StubStreamed(body ?? Uint8List(0));
  }

  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// A streamed answer over an in-memory body.
final class _StubStreamed implements LiveStreamedResponse {
  _StubStreamed(this.body);

  final Uint8List body;

  @override
  int get statusCode => 200;

  @override
  Map<String, String> get headers => const {};

  @override
  Stream<Uint8List> get stream => Stream<Uint8List>.value(body);

  @override
  Future<void> close() async {}
}
