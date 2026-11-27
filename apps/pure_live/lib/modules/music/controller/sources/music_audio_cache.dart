import 'dart:async' show unawaited;
import 'dart:io' show Directory, File, FileSystemException, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show CancelToken, LiveHttp, LiveRequest;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// A file in the cache directory.
typedef CachedAudioFile = ({String name, int size, DateTime modified});

/// The file operations the cache needs, on its own directory. The app
/// implements it with `dart:io` under the cache root; tests use a map.
abstract interface class MusicCacheFiles {
  /// Every file in the directory.
  Future<List<CachedAudioFile>> list();

  /// Size of [name], or null when it does not exist.
  Future<int?> sizeOf(String name);

  /// Renames [from] to [to], replacing [to].
  Future<void> rename(String from, String to);

  /// Deletes [name]; a missing file is not an error.
  Future<void> delete(String name);
}

/// Cache keys: one file per track and quality tier, the reference's shape
/// (`{bvid}_{cid}`) carried over to track ids.
abstract final class MusicAudioCacheKey {
  static final RegExp _unsafe = RegExp('[^A-Za-z0-9_-]');

  /// The key of a track's audio in [quality]; null quality shares the auto
  /// slot, since the source may downgrade the tier anyway.
  static String of(audio.MusicTrack track, audio.MusicQuality? quality) =>
      '${track.sourceId.replaceAll(_unsafe, '')}_${track.id.replaceAll(_unsafe, '')}_${quality?.id ?? 'auto'}';

  /// The finished file of [key].
  static String fileOf(String key) => '$key.audio';

  /// The download in progress of [key]; renamed to [fileOf] only when the
  /// response was written whole, so a partial file is never played.
  static String partOf(String key) => '$key.audio.part';
}

/// What the cache needs from its host, read fresh on every use: the limit
/// changes take effect without a restart, and the transport follows the
/// app's proxy policy like every other network call.
typedef MusicCacheEnvironment = ({Directory directory, int limitMb, LiveHttp http});

/// Persistent audio cache of the music module: a song heard once plays from
/// disk, so it no longer depends on CDN links that expire within minutes.
///
/// At most [maxBytes] is kept, evicting the least recently played files
/// first and never the ones in `keep` (the song playing). Downloads write a
/// `.part` file that becomes the cached file only once the response was
/// written whole.
final class MusicAudioCache {
  /// Creates the cache over [files].
  MusicAudioCache(this.files, {this.maxBytes = 512 * 1024 * 1024, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The directory.
  final MusicCacheFiles files;

  /// Size limit.
  int maxBytes;

  final DateTime Function() _now;
  final Map<String, _CacheEntry> _entries = {};
  final Set<String> _downloading = {};

  /// Bytes in finished files.
  int get totalBytes => _entries.values.fold(0, (sum, entry) => sum + entry.size);

  /// Keys of finished files, least recently used first.
  List<String> get keys =>
      ([..._entries.entries]..sort((a, b) => a.value.used.compareTo(b.value.used))).map((entry) => entry.key).toList();

  /// Reads the directory: finished files join the index (last use = their
  /// modification time), leftover partial files are deleted.
  Future<void> load() async {
    _entries.clear();
    for (final file in await files.list()) {
      if (file.name.endsWith('.part')) {
        await files.delete(file.name);
      } else if (file.name.endsWith('.audio')) {
        _entries[file.name.substring(0, file.name.length - '.audio'.length)] = _CacheEntry(file.size, file.modified);
      }
    }
  }

  /// The file of [key] when it is cached (and marks it used), else null.
  String? lookup(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    entry.used = _now();
    return MusicAudioCacheKey.fileOf(key);
  }

  /// Whether [key] is downloading.
  bool isDownloading(String key) => _downloading.contains(key);

  /// Forgets [key]'s entry without touching any file: the hit whose file
  /// the viewer or a system sweep deleted re-resolves instead of handing
  /// the engine a dead path.
  void forget(String key) {
    _entries.remove(key);
  }

  /// Starts a download of [key]: the partial file name to write, or null
  /// when it is cached or already downloading.
  String? begin(String key) {
    if (_entries.containsKey(key) || !_downloading.add(key)) return null;
    return MusicAudioCacheKey.partOf(key);
  }

  /// The download of [key] finished: the partial file becomes the cached
  /// file (an empty one is dropped), then the cache is trimmed. [keep] is
  /// never evicted.
  Future<void> commit(String key, {Set<String> keep = const {}}) async {
    _downloading.remove(key);
    final part = MusicAudioCacheKey.partOf(key);
    final size = await files.sizeOf(part) ?? 0;
    if (size <= 0) {
      await files.delete(part);
      return;
    }
    await files.rename(part, MusicAudioCacheKey.fileOf(key));
    _entries[key] = _CacheEntry(size, _now());
    await trim(keep: {...keep, key});
  }

  /// The download of [key] failed or was cancelled: its partial file goes.
  Future<void> abort(String key) async {
    _downloading.remove(key);
    await files.delete(MusicAudioCacheKey.partOf(key));
  }

  /// Evicts least recently used files until the cache fits [maxBytes];
  /// [keep] is never evicted.
  Future<void> trim({Set<String> keep = const {}}) async {
    var total = totalBytes;
    for (final key in keys) {
      if (total <= maxBytes) break;
      if (keep.contains(key)) continue;
      total -= _entries.remove(key)!.size;
      await files.delete(MusicAudioCacheKey.fileOf(key));
    }
  }

  /// Empties the cache (downloads in progress finish into it).
  Future<void> clear() async {
    final keys = [..._entries.keys];
    _entries.clear();
    for (final key in keys) {
      try {
        await files.delete(MusicAudioCacheKey.fileOf(key));
      } on FileSystemException {
        // A player may still hold the file open on Windows; keep clearing the rest.
      }
    }
  }
}

final class _CacheEntry {
  _CacheEntry(this.size, this.used);

  final int size;
  DateTime used;
}

/// The `dart:io` [MusicCacheFiles] over [root].
final class DirectoryMusicCacheFiles implements MusicCacheFiles {
  /// Serves the cache under [root].
  DirectoryMusicCacheFiles(this.root);

  /// The cache's own folder.
  final Directory root;

  /// The absolute path of a cache file name.
  String pathOf(String name) => '${root.path}${Platform.pathSeparator}$name';

  @override
  Future<List<CachedAudioFile>> list() async {
    if (!root.existsSync()) return const [];
    final found = <CachedAudioFile>[];
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = entity.statSync();
        found.add((name: entity.uri.pathSegments.last, size: stat.size, modified: stat.modified));
      } on FileSystemException {
        continue;
      }
    }
    return found;
  }

  @override
  Future<int?> sizeOf(String name) async {
    final file = File(pathOf(name));
    if (!file.existsSync()) return null;
    return file.statSync().size;
  }

  @override
  Future<void> rename(String from, String to) async {
    await Future<void>(() => File(pathOf(from)).renameSync(pathOf(to)));
  }

  @override
  Future<void> delete(String name) async {
    await Future<void>(() {
      final file = File(pathOf(name));
      if (file.existsSync()) file.deleteSync();
    });
  }
}

/// The music sources wearing the audio cache: a resolve first asks the
/// disk, and a resolve that reached the network is written into the cache
/// while it plays. Heard-once songs then survive their CDN link expiring.
final class CachedTrackSource extends audio.MusicSource {
  /// Wraps [inner] with a cache box of its own; [environment] is read fresh on
  /// every resolve, and a null (no folder, limit 0) leaves the cache off.
  CachedTrackSource(audio.MusicSource inner, {required MusicCacheEnvironment? Function() environment})
    : this._(inner, environment: environment, box: MusicAudioCacheBox());

  CachedTrackSource._(this.inner, {required this.environment, required MusicAudioCacheBox box}) : _box = box {
    box._sources.add(this);
  }

  /// The platform source the calls ride on.
  final audio.MusicSource inner;

  /// The cache's host facts, read per resolve.
  final MusicCacheEnvironment? Function() environment;

  final MusicAudioCacheBox _box;

  /// The box resolves one cache per directory and capacity, shared by every
  /// source registered in this window.
  Future<MusicAudioCache?> _cacheNow() => _box._cacheFor(this);

  @override
  String get id => inner.id;

  @override
  String get name => inner.name;

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) =>
      inner.search(keyword, page: page, pageSize: pageSize);

  @override
  Future<audio.MusicTrack> trackDetail(audio.MusicTrack track) => inner.trackDetail(track);

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) => inner.qualities(track);

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final cache = await _cacheNow();
    if (cache == null) return await inner.resolveTrackSource(track, quality: quality);
    final key = MusicAudioCacheKey.of(track, quality);
    final file = cache.lookup(key);
    if (file != null) {
      final files = cache.files as DirectoryMusicCacheFiles;
      final path = files.pathOf(file);
      // A hit whose file is gone is a miss: answering it would hand the
      // engine a dead path, which the playback reads as a failed track
      // instead of re-resolving.
      if (File(path).existsSync()) {
        return audio.TrackSource(uri: Uri.file(path), isLocal: true, quality: quality);
      }
      cache.forget(key);
    }
    final source = await inner.resolveTrackSource(track, quality: quality);
    if (!source.isLocal && (source.uri.isScheme('http') || source.uri.isScheme('https'))) {
      unawaited(_download(cache, key, source));
    }
    return source;
  }

  /// Writes [source]'s body into the cache while the song plays; a failure
  /// only costs the copy, never the playback.
  Future<void> _download(MusicAudioCache cache, String key, audio.TrackSource source) async {
    final part = cache.begin(key);
    if (part == null) return;
    final env = environment();
    if (env == null) {
      await cache.abort(key);
      return;
    }
    final files = cache.files as DirectoryMusicCacheFiles;
    final token = CancelToken();
    try {
      final response = await env.http.open(
        LiveRequest.custom(
          method: 'GET',
          url: source.uri,
          headers: source.headers,
          // A CDN stall must end the download, or the key stays parked
          // in the in-flight set until the app restarts.
          timeout: const Duration(seconds: 120),
          cancelToken: token,
        ),
      );
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final sink = File(files.pathOf(part)).openWrite();
      try {
        await response.stream.forEach(sink.add);
      } finally {
        await sink.close();
      }
      await cache.commit(key);
    } on Object catch (error) {
      // A dead download says so: an abort that only freed the key read
      // as never having started, and the next play re-flew it.
      appLog.forCategory('music.cache').warning('audio cache download failed', fields: {'key': key, 'error': '$error'});
      token.cancel();
      await cache.abort(key);
    }
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) => inner.resolveLyric(track);

  @override
  Future<List<audio.MusicCatalog>> catalogs() => inner.catalogs();

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) =>
      inner.catalogItems(catalog, page: page);
}

/// The window's audio-cache box. Playback arms it with the sources it actually
/// resolves through, and the settings page reads and clears that same cache.
final musicAudioCacheBoxProvider = Provider<MusicAudioCacheBox>((ref) {
  final box = MusicAudioCacheBox();
  ref.onDispose(box.disarm);
  return box;
});

typedef _MusicAudioCacheIdentity = ({String directory, int limitMb});

final class MusicAudioCacheBox {
  MusicAudioCacheBox();

  final Set<CachedTrackSource> _sources = {};
  final Map<_MusicAudioCacheIdentity, MusicAudioCache> _caches = {};
  final Map<_MusicAudioCacheIdentity, Future<MusicAudioCache?>?> _loading = {};
  final Map<_MusicAudioCacheIdentity, int> _generations = {};
  CachedTrackSource? _wearing;

  /// The last source assigned through the legacy single-source interface.
  /// Playback uses [register], which accounts for every registered source.
  CachedTrackSource? get wearing => _wearing;

  /// Keeps the old settings/test seam: assigning selects that source for
  /// usage and clear, while registration still retains the whole collection.
  set wearing(CachedTrackSource? source) {
    if (source == null) {
      _wearing = null;
      return;
    }
    _sources.add(source);
    _wearing = source;
  }

  /// The one playback assembly entry: decorates [inner] and registers it in
  /// this window's box, so all platforms resolve through the same ledger.
  CachedTrackSource register(audio.MusicSource inner, {required MusicCacheEnvironment? Function() environment}) =>
      CachedTrackSource._(inner, environment: environment, box: this);

  Iterable<CachedTrackSource> get _accountedSources => _wearing == null ? _sources : [_wearing!];

  static _MusicAudioCacheIdentity _identity(MusicCacheEnvironment environment) =>
      (directory: environment.directory.path, limitMb: environment.limitMb);

  Future<MusicAudioCache?> _cacheFor(CachedTrackSource source) {
    if (!_sources.contains(source)) return Future<MusicAudioCache?>.value();
    final environment = source.environment();
    if (environment == null || environment.limitMb <= 0) return Future<MusicAudioCache?>.value();
    final identity = _identity(environment);
    final loaded = _caches[identity];
    if (loaded != null) return Future<MusicAudioCache?>.value(loaded);
    final pending = _loading[identity];
    if (pending != null) return pending;

    final generation = (_generations[identity] ?? 0) + 1;
    _generations[identity] = generation;
    final loading = () async {
      try {
        final files = DirectoryMusicCacheFiles(
          Directory('${environment.directory.path}${Platform.pathSeparator}music-audio'),
        );
        final cache = MusicAudioCache(files, maxBytes: environment.limitMb * 1024 * 1024);
        await files.root.create(recursive: true);
        await cache.load();
        final current = source.environment();
        if (!_sources.contains(source) ||
            generation != (_generations[identity] ?? 0) ||
            current == null ||
            current.limitMb <= 0 ||
            _identity(current) != identity) {
          return null;
        }
        _caches[identity] = cache;
        return cache;
      } on Object {
        return null;
      } finally {
        if (generation == (_generations[identity] ?? 0)) _loading[identity] = null;
      }
    }();
    _loading[identity] = loading;
    return loading;
  }

  /// Releases every playback source and cached ledger when this window's
  /// scope goes away. In-flight loads cannot publish into the disarmed box.
  void disarm() {
    _sources.clear();
    _wearing = null;
    _caches.clear();
    for (final identity in _loading.keys) {
      _generations[identity] = (_generations[identity] ?? 0) + 1;
    }
    _loading.clear();
  }

  /// Bytes all registered sources' caches hold, counting a shared ledger once;
  /// null while no source has an active cache.
  Future<int?> usageBytes() async {
    final caches = <MusicAudioCache>{};
    for (final source in _accountedSources.toList()) {
      final cache = await _cacheFor(source);
      if (cache != null && _sources.contains(source)) caches.add(cache);
    }
    if (caches.isEmpty) return null;
    return caches.fold<int>(0, (sum, cache) => sum + cache.totalBytes);
  }

  /// Empties every accounted source's cache, clearing a shared ledger once.
  Future<void> clear() async {
    final caches = <MusicAudioCache>{};
    for (final source in _accountedSources.toList()) {
      final cache = await _cacheFor(source);
      if (cache != null && _sources.contains(source)) caches.add(cache);
    }
    for (final cache in caches) {
      await cache.clear();
    }
  }
}
